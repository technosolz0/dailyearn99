// Configuration
const API_BASE = '/api';

// State management
let state = {
    activeTab: 'overview',
    users: [],
    contests: [],
    withdrawals: []
};

// Elements
const el = {
    get tabs() { return document.querySelectorAll('.menu-item'); },
    get panels() { return document.querySelectorAll('.tab-panel'); },
    get pageTitle() { return document.getElementById('page-title'); },
    get pageSubtitle() { return document.getElementById('page-subtitle'); },
    get btnRefresh() { return document.getElementById('btn-refresh'); },
    get toast() { return document.getElementById('toast'); },

    // Stats
    get statUsers() { return document.getElementById('stat-users'); },
    get statDeposits() { return document.getElementById('stat-deposits'); },
    get statContests() { return document.getElementById('stat-contests'); },
    get statWinnings() { return document.getElementById('stat-winnings'); },
    get statRevenue() { return document.getElementById('stat-revenue'); },

    // Forms
    get quickContestForm() { return document.getElementById('quick-contest-form'); },

    // Tables
    get usersTable() { return document.getElementById('users-table-body'); },
    get contestsTable() { return document.getElementById('contests-table-body'); },
    get withdrawalsTable() { return document.getElementById('withdrawals-table-body'); },
    get transactionsTable() { return document.getElementById('transactions-table-body'); },
    get userSearch() { return document.getElementById('user-search'); },

    // Modal
    get btnOpenCreateModal() { return document.getElementById('btn-open-create-modal'); },
    get createContestModal() { return document.getElementById('create-contest-modal'); },
    get btnCloseModal() { return document.getElementById('btn-close-modal'); },
    get modalContestForm() { return document.getElementById('modal-contest-form'); },
    get btnAddPrizeRule() { return document.getElementById('btn-add-prize-rule'); },
    get prizeRulesList() { return document.getElementById('prize-rules-list'); },
    get btnAddQuestion() { return document.getElementById('btn-add-question'); },
    get quizQuestionsList() { return document.getElementById('quiz-questions-list'); }
};

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
    setupTabNavigation();
    setupEventHandlers();
    loadDashboardData();

    // Automatically poll stats every 30 seconds
    setInterval(loadDashboardData, 30000);
});

// Toast Notifications
function showToast(message, isError = false) {
    el.toast.innerText = message;
    el.toast.style.borderLeftColor = isError ? 'var(--error)' : 'var(--primary)';
    el.toast.classList.add('show');

    setTimeout(() => {
        el.toast.classList.remove('show');
    }, 3500);
}

// Tab Navigation
function setupTabNavigation() {
    el.tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const targetTab = tab.getAttribute('data-tab');
            if (state.activeTab === targetTab) return;

            // Update active menu items
            el.tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            // Update active panel
            el.panels.forEach(p => p.classList.remove('active'));
            document.getElementById(`panel-${targetTab}`).classList.add('active');

            state.activeTab = targetTab;
            updateHeaders(targetTab);

            // Trigger specific loading for tab
            loadTabSpecificData(targetTab);
        });
    });
}

function updateHeaders(tab) {
    switch (tab) {
        case 'overview':
            el.pageTitle.innerText = "Platform Overview";
            el.pageSubtitle.innerText = "Real-time statistics & business metrics";
            break;
        case 'users':
            el.pageTitle.innerText = "User Management";
            el.pageSubtitle.innerText = "View user records, wallet balances, and issue bans";
            break;
        case 'contests':
            el.pageTitle.innerText = "Contest Engine";
            el.pageSubtitle.innerText = "Monitor active game lobbies and track players";
            break;
        case 'withdrawals':
            el.pageTitle.innerText = "Financial Transactions Log";
            el.pageSubtitle.innerText = "Approve withdrawals and view complete deposit & withdrawal ledger";
            break;
        case 'notifications':
            el.pageTitle.innerText = "Notification Center";
            el.pageSubtitle.innerText = "Send custom Firebase push messages directly to client devices";
            break;
    }
}

// Event Handlers Setup
function setupEventHandlers() {
    el.btnRefresh.addEventListener('click', () => {
        el.btnRefresh.classList.add('spinning');
        loadDashboardData().then(() => {
            setTimeout(() => el.btnRefresh.classList.remove('spinning'), 500);
            showToast("System metrics synchronized.");
        });
    });

    // Quick Contest Form Submission
    if (el.quickContestForm) {
        el.quickContestForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            const title = document.getElementById('c-title').value;
            const entryFee = parseFloat(document.getElementById('c-fee').value);
            const totalSlots = parseInt(document.getElementById('c-slots').value);
            const prizePool = parseFloat(document.getElementById('c-pool').value);

            // Set start time to 30 mins in future
            const startTime = new Date(Date.now() + 30 * 60 * 1000).toISOString();

            try {
                const response = await fetch(`${API_BASE}/admin/contests`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        title,
                        entry_fee: entryFee,
                        total_slots: totalSlots,
                        prize_pool: prizePool,
                        start_time: startTime
                    })
                });

                if (!response.ok) throw new Error(await response.text());

                showToast("Contest created and deployed successfully!");
                el.quickContestForm.reset();

                // Reload data if on overview/contests tab
                loadDashboardData();
            } catch (err) {
                console.error(err);
                showToast("Failed to create contest: " + err.message, true);
            }
        });
    }

    // Push Notification Recipient toggle
    const recipientType = document.getElementById('push-recipient-type');
    const userIdGroup = document.getElementById('push-user-id-group');
    if (recipientType && userIdGroup) {
        recipientType.addEventListener('change', (e) => {
            if (e.target.value === 'user') {
                userIdGroup.style.display = 'block';
            } else {
                userIdGroup.style.display = 'none';
            }
        });
    }

    // Send Push Notification Click
    const btnSendPush = document.getElementById('btn-send-push');
    if (btnSendPush) {
        btnSendPush.addEventListener('click', async () => {
            const type = document.getElementById('push-recipient-type').value;
            const title = document.getElementById('push-title').value.trim();
            const body = document.getElementById('push-body').value.trim();

            if (!title || !body) {
                showToast("Please enter both title and body.", true);
                return;
            }

            btnSendPush.disabled = true;
            btnSendPush.innerText = "Sending...";

            try {
                let endpoint, payload;
                if (type === 'user') {
                    const userId = parseInt(document.getElementById('push-user-id').value);
                    if (isNaN(userId)) {
                        showToast("Please enter a valid User ID.", true);
                        btnSendPush.disabled = false;
                        btnSendPush.innerText = "Send Notification";
                        return;
                    }
                    endpoint = `${API_BASE}/admin/notifications/send-user`;
                    payload = { user_id: userId, title, body };
                } else {
                    endpoint = `${API_BASE}/admin/notifications/send-all`;
                    payload = { title, body };
                }

                const res = await fetch(endpoint, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });

                if (!res.ok) {
                    const errorText = await res.text();
                    throw new Error(errorText || "Server error");
                }

                showToast("Notification request processed!");
                document.getElementById('push-title').value = '';
                document.getElementById('push-body').value = '';
                if (type === 'user') {
                    document.getElementById('push-user-id').value = '';
                }
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btnSendPush.disabled = false;
                btnSendPush.innerText = "Send Notification";
            }
        });
    }

    // Search Filter
    el.userSearch.addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase();
        filterUsersTable(query);
    });

    // Modal Event Handlers
    if (el.btnOpenCreateModal) {
        el.btnOpenCreateModal.addEventListener('click', () => {
            // Reset form and empty dynamic prize rules and quiz questions
            el.modalContestForm.reset();
            el.prizeRulesList.innerHTML = '';
            el.quizQuestionsList.innerHTML = '';

            // Set default date-time to 2 hours from now
            const localOffset = new Date().getTimezoneOffset() * 60000; // in ms
            const localISOTime = new Date(Date.now() + 2 * 60 * 60 * 1000 - localOffset).toISOString().slice(0, 16);
            document.getElementById('m-start-time').value = localISOTime;

            // Open modal
            el.createContestModal.classList.add('show');
        });
    }

    if (el.btnCloseModal) {
        el.btnCloseModal.addEventListener('click', () => {
            el.createContestModal.classList.remove('show');
        });
    }

    // Dynamic Prize Rule row adding
    if (el.btnAddPrizeRule) {
        el.btnAddPrizeRule.addEventListener('click', () => {
            // UX: auto-calculate next min rank
            const rows = el.prizeRulesList.querySelectorAll('.prize-rule-row');
            let nextMin = 1;
            if (rows.length > 0) {
                const lastMaxInput = rows[rows.length - 1].querySelector('.rule-max-rank');
                const lastMax = parseInt(lastMaxInput.value);
                if (!isNaN(lastMax)) {
                    nextMin = lastMax + 1;
                }
            }

            const row = document.createElement('div');
            row.className = 'prize-rule-row';
            row.innerHTML = `
                <input type="number" placeholder="Min" class="rule-min-rank" min="1" value="${nextMin}" required style="padding: 6px 8px;">
                <span>to</span>
                <input type="number" placeholder="Max" class="rule-max-rank" min="1" value="${nextMin}" required style="padding: 6px 8px;">
                <input type="number" placeholder="Prize (₹)" class="rule-prize" min="0" required style="padding: 6px 8px;">
                <button type="button" class="btn-remove-rule" title="Remove Rule">&times;</button>
            `;

            row.querySelector('.btn-remove-rule').addEventListener('click', () => {
                row.remove();
            });

            const minInput = row.querySelector('.rule-min-rank');
            const maxInput = row.querySelector('.rule-max-rank');
            minInput.addEventListener('input', () => {
                if (maxInput.value === minInput.dataset.prevMin || maxInput.value === '') {
                    maxInput.value = minInput.value;
                }
                minInput.dataset.prevMin = minInput.value;
            });
            minInput.dataset.prevMin = minInput.value;

            el.prizeRulesList.appendChild(row);
            el.prizeRulesList.scrollTop = el.prizeRulesList.scrollHeight;
        });
    }

    // Dynamic Quiz Question card adding
    if (el.btnAddQuestion) {
        el.btnAddQuestion.addEventListener('click', () => {
            const card = document.createElement('div');
            card.className = 'quiz-question-card';
            card.innerHTML = `
                <div class="question-header">
                    <input type="text" placeholder="Question Text (e.g. Which programming language is predominantly used to write Flutter apps?)" class="q-text" required>
                    <button type="button" class="btn-remove-rule btn-remove-question" title="Remove Question">&times;</button>
                </div>
                <div class="question-options-grid">
                    <input type="text" placeholder="Option A" class="q-opt-0" required>
                    <input type="text" placeholder="Option B" class="q-opt-1" required>
                    <input type="text" placeholder="Option C" class="q-opt-2" required>
                    <input type="text" placeholder="Option D" class="q-opt-3" required>
                </div>
                <div class="question-footer">
                    <div class="correct-select-wrapper">
                        <span style="font-size:12px; color:var(--text-muted);">Correct Answer:</span>
                        <select class="q-correct">
                            <option value="0">Option A</option>
                            <option value="1">Option B</option>
                            <option value="2">Option C</option>
                            <option value="3">Option D</option>
                        </select>
                    </div>
                </div>
            `;

            card.querySelector('.btn-remove-question').addEventListener('click', () => {
                card.remove();
            });

            el.quizQuestionsList.appendChild(card);
            el.quizQuestionsList.scrollTop = el.quizQuestionsList.scrollHeight;
        });
    }

    if (el.modalContestForm) {
        el.modalContestForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            const title = document.getElementById('m-title').value.trim();
            const entryFee = parseFloat(document.getElementById('m-fee').value);
            const totalSlots = parseInt(document.getElementById('m-slots').value);
            const prizePool = parseFloat(document.getElementById('m-pool').value);
            const startTimeStr = document.getElementById('m-start-time').value;

            if (!title || isNaN(entryFee) || isNaN(totalSlots) || isNaN(prizePool) || !startTimeStr) {
                showToast("Please fill all required fields correctly.", true);
                return;
            }

            const startTime = new Date(startTimeStr).toISOString();

            // Collect prize rules
            const prizeRules = [];
            const rows = el.prizeRulesList.querySelectorAll('.prize-rule-row');
            for (const r of rows) {
                const minRank = parseInt(r.querySelector('.rule-min-rank').value);
                const maxRank = parseInt(r.querySelector('.rule-max-rank').value);
                const prize = parseFloat(r.querySelector('.rule-prize').value);

                if (isNaN(minRank) || isNaN(maxRank) || isNaN(prize)) {
                    showToast("Please verify all prize rule values are valid numbers.", true);
                    return;
                }
                if (minRank > maxRank) {
                    showToast(`Rule min rank (${minRank}) cannot be greater than max rank (${maxRank}).`, true);
                    return;
                }

                prizeRules.push({
                    min_rank: minRank,
                    max_rank: maxRank,
                    prize: prize
                });
            }

            // Collect quiz questions
            const questions = [];
            const qCards = el.quizQuestionsList.querySelectorAll('.quiz-question-card');
            for (const card of qCards) {
                const text = card.querySelector('.q-text').value.trim();
                const opt0 = card.querySelector('.q-opt-0').value.trim();
                const opt1 = card.querySelector('.q-opt-1').value.trim();
                const opt2 = card.querySelector('.q-opt-2').value.trim();
                const opt3 = card.querySelector('.q-opt-3').value.trim();
                const correctAnswerIndex = parseInt(card.querySelector('.q-correct').value);

                if (!text || !opt0 || !opt1 || !opt2 || !opt3 || isNaN(correctAnswerIndex)) {
                    showToast("Please fill all fields in the quiz questions section.", true);
                    return;
                }

                questions.push({
                    text: text,
                    options: [opt0, opt1, opt2, opt3],
                    correct_answer_index: correctAnswerIndex
                });
            }

            try {
                const response = await fetch(`${API_BASE}/admin/contests`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        title,
                        entry_fee: entryFee,
                        total_slots: totalSlots,
                        prize_pool: prizePool,
                        start_time: startTime,
                        prize_rules: prizeRules.length > 0 ? prizeRules : null,
                        questions: questions.length > 0 ? questions : null
                    })
                });

                if (!response.ok) throw new Error(await response.text());

                showToast("New contest deployed successfully!");
                el.createContestModal.classList.remove('show');
                el.modalContestForm.reset();
                el.prizeRulesList.innerHTML = '';

                loadDashboardData();
            } catch (err) {
                console.error(err);
                showToast("Failed to deploy contest: " + err.message, true);
            }
        });
    }

    // Adjust Balance Modal Close & Submit Actions
    const btnCloseBalanceModal = document.getElementById('btn-close-balance-modal');
    const adjustBalanceModal = document.getElementById('adjust-balance-modal');
    if (btnCloseBalanceModal && adjustBalanceModal) {
        btnCloseBalanceModal.addEventListener('click', () => {
            adjustBalanceModal.classList.remove('show');
        });
    }

    const modalAdjustBalanceForm = document.getElementById('modal-adjust-balance-form');
    if (modalAdjustBalanceForm) {
        modalAdjustBalanceForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const userId = parseInt(document.getElementById('adj-user-id').value);
            const walletType = document.getElementById('adj-wallet-type').value;
            const amount = parseFloat(document.getElementById('adj-amount').value);

            if (isNaN(userId) || isNaN(amount)) {
                showToast("Please enter a valid amount.", true);
                return;
            }

            try {
                const response = await fetch(`${API_BASE}/admin/users/${userId}/adjust-balance`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        amount: amount,
                        wallet_type: walletType
                    })
                });

                if (!response.ok) throw new Error(await response.text());

                showToast(`Successfully adjusted ${walletType} balance by ₹${amount.toFixed(2)}!`);
                adjustBalanceModal.classList.remove('show');
                loadUsers();
            } catch (err) {
                console.error(err);
                showToast("Failed to adjust balance: " + err.message, true);
            }
        });
    }
}

// Data loading
async function loadDashboardData() {
    try {
        // Fetch stats
        const statsRes = await fetch(`${API_BASE}/admin/stats`);
        if (!statsRes.ok) throw new Error("Failed to load statistics.");
        const stats = await statsRes.json();

        // Render stats
        el.statUsers.innerText = stats.total_users;
        el.statDeposits.innerText = `₹${stats.total_deposits.toFixed(2)}`;
        el.statContests.innerText = stats.active_contests;
        el.statWinnings.innerText = `₹${stats.total_winnings_paid.toFixed(2)}`;
        el.statRevenue.innerText = `₹${stats.total_revenue.toFixed(2)}`;

        // Change color based on positive/negative revenue
        if (stats.total_revenue < 0) {
            el.statRevenue.style.color = 'var(--error)';
        } else {
            el.statRevenue.style.color = 'var(--success)';
        }

        // Load active tab data
        loadTabSpecificData(state.activeTab);
    } catch (err) {
        console.error(err);
        showToast(err.message, true);
    }
}

function loadTabSpecificData(tab) {
    switch (tab) {
        case 'users':
            loadUsers();
            break;
        case 'contests':
            loadContests();
            break;
        case 'withdrawals':
            loadWithdrawals();
            break;
    }
}

// 1. Users Operations
async function loadUsers() {
    try {
        const res = await fetch(`${API_BASE}/admin/users`);
        if (!res.ok) throw new Error("Failed to load users list.");
        state.users = await res.json();
        renderUsersTable(state.users);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderUsersTable(usersList) {
    if (usersList.length === 0) {
        el.usersTable.innerHTML = `<tr><td colspan="6" class="table-placeholder">No accounts registered yet.</td></tr>`;
        return;
    }

    el.usersTable.innerHTML = usersList.map(u => {
        const banBtn = u.is_banned
            ? `<button class="btn btn-action btn-unban" onclick="toggleBan(${u.id}, false)">Unban User</button>`
            : `<button class="btn btn-action btn-ban" onclick="toggleBan(${u.id}, true)">Ban User</button>`;

        return `
            <tr>
                <td>${u.id}</td>
                <td>
                    <div class="user-cell">
                        <span class="user-name">${u.name || 'Anonymous User'}</span>
                        <span class="user-phone">${u.phone} (Code: ${u.referral_code})</span>
                    </div>
                </td>
                <td>
                    <div class="balance-grid">
                        <div class="bal-item">
                            <div class="bal-lbl">Deposit</div>
                            <div class="bal-val dep">₹${u.deposit_balance.toFixed(2)}</div>
                        </div>
                        <div class="bal-item">
                            <div class="bal-lbl">Winnings</div>
                            <div class="bal-val win">₹${u.winning_balance.toFixed(2)}</div>
                        </div>
                        <div class="bal-item">
                            <div class="bal-lbl">Bonus</div>
                            <div class="bal-val bon">₹${u.bonus_balance.toFixed(2)}</div>
                        </div>
                    </div>
                </td>
                <td>
                    <span class="badge ${u.kyc_status === 'VERIFIED' ? 'badge-success' : 'badge-warning'}">
                        ${u.kyc_status}
                    </span>
                </td>
                <td>${u.referred_by ? `<span class="badge badge-info">${u.referred_by}</span>` : '<span class="text-muted">-</span>'}</td>
                <td>
                    <div style="display: flex; gap: 8px; align-items: center;">
                        ${banBtn}
                        <button class="btn btn-action" style="background-color: rgba(0, 210, 255, 0.1); color: var(--primary); border: 1px solid rgba(0, 210, 255, 0.2);" onclick="openAdjustBalanceModal(${u.id}, '${u.name ? u.name.replace(/'/g, "\\'") : 'Anonymous'}', '${u.phone}')">Adjust Balance</button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function filterUsersTable(query) {
    const filtered = state.users.filter(u =>
        u.phone.includes(query) ||
        (u.name && u.name.toLowerCase().includes(query)) ||
        u.referral_code.toLowerCase().includes(query)
    );
    renderUsersTable(filtered);
}

async function toggleBan(userId, ban) {
    try {
        const res = await fetch(`${API_BASE}/admin/users/${userId}/ban?ban=${ban}`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error("Failed to ban/unban user.");

        showToast(ban ? "User account has been banned." : "User account active.");
        loadUsers();
    } catch (err) {
        showToast(err.message, true);
    }
}

// 2. Contests Operations
async function loadContests() {
    try {
        const res = await fetch(`${API_BASE}/contests`);
        if (!res.ok) throw new Error("Failed to load contests.");
        state.contests = await res.json();
        renderContestsTable(state.contests);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderContestsTable(contestsList) {
    if (contestsList.length === 0) {
        el.contestsTable.innerHTML = `<tr><td colspan="8" class="table-placeholder">No contests defined yet.</td></tr>`;
        return;
    }

    el.contestsTable.innerHTML = contestsList.map(c => {
        let statusBadge = 'badge-warning';
        if (c.status === 'ACTIVE') statusBadge = 'badge-success';
        if (c.status === 'COMPLETED') statusBadge = 'badge-info';

        const startTimeStr = new Date(c.start_time).toLocaleString();

        const actionBtn = c.status !== 'COMPLETED'
            ? `<button class="btn btn-action btn-unban" onclick="completeContest(${c.id})">Complete</button>`
            : `<span class="text-muted" style="font-size:12px;">Payout Done</span>`;

        let rulesHtml = '';
        if (c.prize_rules && c.prize_rules.length > 0) {
            rulesHtml = `<div style="font-size: 11px; color: var(--text-muted); margin-top: 5px; display: flex; flex-direction: column; gap: 2px;">` +
                c.prize_rules.map(r => `<span>Rank ${r.min_rank}${r.min_rank === r.max_rank ? '' : '-' + r.max_rank}: ₹${r.prize}</span>`).join('') +
                `</div>`;
        } else {
            rulesHtml = `<span style="font-size: 11px; color: var(--text-muted); font-style: italic; margin-top: 5px; display: block;">Standard distribution</span>`;
        }

        const questionsCount = c.questions ? c.questions.length : 0;
        const questionsHtml = `<div style="font-size: 11px; color: var(--text-muted); margin-top: 3px;">📋 ${questionsCount} Questions</div>`;

        return `
            <tr>
                <td>${c.id}</td>
                <td>
                    <strong style="font-size:14px;">${c.title}</strong>
                    ${questionsHtml}
                </td>
                <td>₹${c.entry_fee.toFixed(2)}</td>
                <td>
                    <div class="user-cell">
                        <span>${c.joined_slots} / ${c.total_slots} filled</span>
                        <div style="background-color: rgba(255,255,255,0.05); width:120px; height:4px; border-radius:2px; margin-top:4px; overflow:hidden;">
                            <div style="background:var(--primary); height:100%; width: ${(c.joined_slots / c.total_slots) * 100}%"></div>
                        </div>
                    </div>
                </td>
                <td>
                    <strong>₹${c.prize_pool.toFixed(2)}</strong>
                    ${rulesHtml}
                </td>
                <td>${startTimeStr}</td>
                <td><span class="badge ${statusBadge}">${c.status}</span></td>
                <td>
                    <div style="display:flex; gap:8px;">
                        ${actionBtn}
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

// 3. Payout/Withdrawal Operations
// 3. Payout/Withdrawal Operations & Transactions Log
async function loadWithdrawals() {
    try {
        // Fetch users first to map user details
        const usersRes = await fetch(`${API_BASE}/admin/users`);
        if (usersRes.ok) {
            state.users = await usersRes.json();
        }

        // Fetch all transactions
        const res = await fetch(`${API_BASE}/admin/transactions`);
        if (!res.ok) throw new Error("Failed to load transactions history.");
        const allTransactions = await res.json();

        // Filter pending withdrawals for approvals table
        const pendingWithdrawals = allTransactions.filter(t => t.type === 'WITHDRAWAL' && t.status === 'PENDING');
        renderWithdrawalsTable(pendingWithdrawals);

        // Render completed history table
        renderTransactionHistoryTable(allTransactions);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderWithdrawalsTable(withdrawalsList) {
    if (withdrawalsList.length === 0) {
        el.withdrawalsTable.innerHTML = `<tr><td colspan="6" class="table-placeholder">No pending withdrawals.</td></tr>`;
        return;
    }

    el.withdrawalsTable.innerHTML = withdrawalsList.map(w => {
        const dateStr = new Date(w.created_at).toLocaleString();
        const userObj = state.users.find(u => u.id === w.user_id);
        const userDetails = userObj ? `${userObj.name || 'Anonymous'} (${userObj.phone})` : `User #${w.user_id}`;

        let actions = `
            <div style="display:flex; gap: 8px;">
                <button class="btn btn-action btn-unban" onclick="approveWithdrawal(${w.id}, true)">Approve</button>
                <button class="btn btn-action btn-ban" onclick="approveWithdrawal(${w.id}, false)">Reject</button>
            </div>
        `;

        return `
            <tr>
                <td>#${w.id}</td>
                <td>${userDetails}</td>
                <td><strong style="color:var(--error)">₹${w.amount.toFixed(2)}</strong></td>
                <td>${dateStr}</td>
                <td><span class="badge badge-warning">PENDING</span></td>
                <td>${actions}</td>
            </tr>
        `;
    }).join('');
}

function renderTransactionHistoryTable(txList) {
    if (!el.transactionsTable) return;

    if (txList.length === 0) {
        el.transactionsTable.innerHTML = `<tr><td colspan="6" class="table-placeholder">No transactions found.</td></tr>`;
        return;
    }

    el.transactionsTable.innerHTML = txList.map(tx => {
        const dateStr = new Date(tx.created_at).toLocaleString();
        const userObj = state.users.find(u => u.id === tx.user_id);
        const userDetails = userObj ? `${userObj.name || 'Anonymous'} (${userObj.phone})` : `User #${tx.user_id}`;

        let statusBadge = 'badge-warning';
        if (tx.status === 'SUCCESS') statusBadge = 'badge-success';
        if (tx.status === 'FAILED') statusBadge = 'badge-error';

        const typeBadge = tx.type === 'DEPOSIT' ? 'badge-success' : 'badge-error';
        const typeStyle = tx.type === 'DEPOSIT' ? 'color: var(--success)' : 'color: var(--error)';
        const prefix = tx.type === 'DEPOSIT' ? '+' : '-';

        return `
            <tr>
                <td>#${tx.id}</td>
                <td>${userDetails}</td>
                <td><span class="badge ${typeBadge}">${tx.type}</span></td>
                <td><strong style="${typeStyle}">${prefix}₹${tx.amount.toFixed(2)}</strong></td>
                <td><span class="badge ${statusBadge}">${tx.status}</span></td>
                <td>${dateStr}</td>
            </tr>
        `;
    }).join('');
}

async function approveWithdrawal(txId, approve) {
    try {
        const res = await fetch(`${API_BASE}/admin/withdrawals/${txId}/approve?approve=${approve}`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error("Failed to process withdrawal action.");

        showToast(approve ? "Withdrawal payout approved!" : "Withdrawal rejected & refunded.");
        loadDashboardData();
    } catch (err) {
        showToast(err.message, true);
    }
}

async function completeContest(contestId) {
    if (!confirm("Are you sure you want to complete this contest and pay out the winners?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/contests/${contestId}/complete`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Contest completed and payouts distributed!");
        loadDashboardData();
    } catch (err) {
        showToast("Error completing contest: " + err.message, true);
    }
}

// Adjust Balance Modal Actions
window.openAdjustBalanceModal = function (userId, name, phone) {
    document.getElementById('adj-user-id').value = userId;
    document.getElementById('adj-user-details').innerText = `${name} (${phone}) - ID: ${userId}`;
    document.getElementById('adj-amount').value = '';
    document.getElementById('adj-wallet-type').value = 'deposit';
    document.getElementById('adjust-balance-modal').classList.add('show');
}

