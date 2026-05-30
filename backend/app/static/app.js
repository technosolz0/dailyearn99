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
    get depositsTable() { return document.getElementById('deposits-table-body'); },
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
        case 'quiz-manager':
            el.pageTitle.innerText = "Quiz Manager";
            el.pageSubtitle.innerText = "Manage questions and options for each contest";
            break;
        case 'wallet-manager':
            el.pageTitle.innerText = "Wallet Manager";
            el.pageSubtitle.innerText = "Directly adjust deposit, winning, or bonus balances for any user account";
            break;
        case 'spin-engine':
            el.pageTitle.innerText = "Casino Spin Engine Controller";
            el.pageSubtitle.innerText = "Configure RTP settings, monitor platform revenue, and review gaming logs";
            break;
        case 'fruit-manager':
            el.pageTitle.innerText = "Fruit Slicing Manager";
            el.pageSubtitle.innerText = "Manage Fruit Slicing tournaments, create new contests, and payout prizes";
            break;
        case 'puzzle-manager':
            el.pageTitle.innerText = "Slide Puzzle Manager";
            el.pageSubtitle.innerText = "Manage slide puzzle matches, configure image assets, and award winnings";
            break;
        case 'word-manager':
            el.pageTitle.innerText = "Word Puzzle Manager";
            el.pageSubtitle.innerText = "Manage word puzzle contest lobbies, design vocabularies, and distribute rewards";
            break;
    }
}

// Event Handlers Setup
function setupEventHandlers() {
    if (el.btnRefresh) {
        el.btnRefresh.addEventListener('click', () => {
            el.btnRefresh.classList.add('spinning');
            loadDashboardData().then(() => {
                setTimeout(() => el.btnRefresh.classList.remove('spinning'), 500);
                showToast("System metrics synchronized.");
            });
        });
    }

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
            // Set end time to 60 mins in future
            const endTime = new Date(Date.now() + 60 * 60 * 1000).toISOString();

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
                        end_time: endTime
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
    if (el.userSearch) {
        el.userSearch.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            filterUsersTable(query);
        });
    }

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

            const localEndISOTime = new Date(Date.now() + 3 * 60 * 60 * 1000 - localOffset).toISOString().slice(0, 16);
            document.getElementById('m-end-time').value = localEndISOTime;

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
            const endTimeStr = document.getElementById('m-end-time').value;

            if (!title || isNaN(entryFee) || isNaN(totalSlots) || isNaN(prizePool) || !startTimeStr) {
                showToast("Please fill all required fields correctly.", true);
                return;
            }

            const startTime = new Date(startTimeStr).toISOString();
            const endTime = endTimeStr ? new Date(endTimeStr).toISOString() : null;

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
                        end_time: endTime,
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

    // ==========================================
    // NEW GAME MANAGERS EVENT LISTENERS
    // ==========================================

    // 1. Add Prize Rule Listeners
    const btnFCAddRule = document.getElementById('btn-fc-add-prize-rule');
    if (btnFCAddRule) {
        btnFCAddRule.addEventListener('click', () => addPrizeRuleRow('fc-prize-rules-list'));
    }
    const btnPCAddRule = document.getElementById('btn-pc-add-prize-rule');
    if (btnPCAddRule) {
        btnPCAddRule.addEventListener('click', () => addPrizeRuleRow('pc-prize-rules-list'));
    }
    const btnWCAddRule = document.getElementById('btn-wc-add-prize-rule');
    if (btnWCAddRule) {
        btnWCAddRule.addEventListener('click', () => addPrizeRuleRow('wc-prize-rules-list'));
    }

    // 2. Image URL Preview for Slide Puzzle
    const pcImageUrlInput = document.getElementById('pc-image-url');
    const pcImagePreview = document.getElementById('pc-image-preview');
    if (pcImageUrlInput && pcImagePreview) {
        pcImageUrlInput.addEventListener('input', (e) => {
            pcImagePreview.src = e.target.value.trim() || 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop';
        });
    }

    // Helper to collect prize rules from list container
    function collectPrizeRules(listContainerId) {
        const rules = [];
        const rows = document.getElementById(listContainerId).querySelectorAll('.prize-rule-row');
        for (const r of rows) {
            const minRank = parseInt(r.querySelector('.rule-min-rank').value);
            const maxRank = parseInt(r.querySelector('.rule-max-rank').value);
            const prize = parseFloat(r.querySelector('.rule-prize').value);
            if (isNaN(minRank) || isNaN(maxRank) || isNaN(prize)) continue;
            rules.push({ min_rank: minRank, max_rank: maxRank, prize: prize });
        }
        return rules;
    }

    // 3. Launch Fruit Contest Form Submit
    const fcForm = document.getElementById('fruit-contest-form');
    if (fcForm) {
        fcForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const title = document.getElementById('fc-title').value.trim();
            const entryFee = parseFloat(document.getElementById('fc-fee').value);
            const totalSlots = parseInt(document.getElementById('fc-slots').value);
            const prizePool = parseFloat(document.getElementById('fc-pool').value);
            const duration = parseInt(document.getElementById('fc-duration').value);
            const startTimeStr = document.getElementById('fc-start-time').value;
            const endTimeStr = document.getElementById('fc-end-time').value;

            const prizeRules = collectPrizeRules('fc-prize-rules-list');

            const payload = {
                title,
                entry_fee: entryFee,
                total_slots: totalSlots,
                prize_pool: prizePool,
                duration_seconds: duration,
                start_time: new Date(startTimeStr).toISOString(),
                end_time: endTimeStr ? new Date(endTimeStr).toISOString() : null,
                prize_rules: prizeRules
            };

            const btn = fcForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Launching...";

            try {
                const res = await fetch(`${API_BASE}/admin/fruit-slicing/contests`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error(await res.text());

                showToast("Fruit slicing tournament launched successfully!");
                fcForm.reset();
                document.getElementById('fc-prize-rules-list').innerHTML = '';
                loadFruitManager();
            } catch (err) {
                showToast("Failed to launch: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Launch Fruit Tournament";
            }
        });
    }

    // 4. Launch Slide Puzzle Contest Form Submit
    const pcForm = document.getElementById('puzzle-contest-form');
    if (pcForm) {
        pcForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const title = document.getElementById('pc-title').value.trim();
            const imageUrl = document.getElementById('pc-image-url').value.trim();
            const entryFee = parseFloat(document.getElementById('pc-fee').value);
            const totalSlots = parseInt(document.getElementById('pc-slots').value);
            const prizePool = parseFloat(document.getElementById('pc-pool').value);
            const gridSize = parseInt(document.getElementById('pc-grid-size').value);
            const duration = parseInt(document.getElementById('pc-duration').value);
            const startTimeStr = document.getElementById('pc-start-time').value;
            const endTimeStr = document.getElementById('pc-end-time').value;

            const prizeRules = collectPrizeRules('pc-prize-rules-list');

            const payload = {
                title,
                image_url: imageUrl,
                entry_fee: entryFee,
                total_slots: totalSlots,
                prize_pool: prizePool,
                grid_size: gridSize,
                duration_seconds: duration,
                start_time: new Date(startTimeStr).toISOString(),
                end_time: endTimeStr ? new Date(endTimeStr).toISOString() : null,
                prize_rules: prizeRules
            };

            const btn = pcForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Launching...";

            try {
                const res = await fetch(`${API_BASE}/admin/puzzle/contests`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error(await res.text());

                showToast("Slide puzzle tournament launched successfully!");
                pcForm.reset();
                document.getElementById('pc-prize-rules-list').innerHTML = '';
                if (pcImagePreview) pcImagePreview.src = 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500&auto=format&fit=crop';
                loadPuzzleManager();
            } catch (err) {
                showToast("Failed to launch: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Launch Puzzle Contest";
            }
        });
    }

    // 5. Launch Word Contest Form Submit
    const wcForm = document.getElementById('word-contest-form');
    if (wcForm) {
        wcForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const title = document.getElementById('wc-title').value.trim();
            const entryFee = parseFloat(document.getElementById('wc-fee').value);
            const totalSlots = parseInt(document.getElementById('wc-slots').value);
            const prizePool = parseFloat(document.getElementById('wc-pool').value);
            const difficulty = document.getElementById('wc-difficulty').value;
            const duration = parseInt(document.getElementById('wc-duration').value);
            const startTimeStr = document.getElementById('wc-start-time').value;
            const endTimeStr = document.getElementById('wc-end-time').value;

            const prizeRules = collectPrizeRules('wc-prize-rules-list');

            const payload = {
                title,
                entry_fee: entryFee,
                total_slots: totalSlots,
                prize_pool: prizePool,
                difficulty,
                duration_seconds: duration,
                start_time: new Date(startTimeStr).toISOString(),
                end_time: new Date(endTimeStr).toISOString(),
                prize_rules: prizeRules
            };

            const btn = wcForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Launching...";

            try {
                const res = await fetch(`${API_BASE}/admin/word-puzzle/contests`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error(await res.text());

                showToast("Word guessing tournament launched successfully!");
                wcForm.reset();
                document.getElementById('wc-prize-rules-list').innerHTML = '';
                loadWordManager();
            } catch (err) {
                showToast("Failed to launch: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Launch Word Contest";
            }
        });
    }

    // 6. Word Question Editor - Contest Select Dropdown
    const wqcContestSelect = document.getElementById('wqc-contest-select');
    if (wqcContestSelect) {
        wqcContestSelect.addEventListener('change', (e) => {
            const val = parseInt(e.target.value);
            if (isNaN(val)) {
                document.getElementById('wqc-questions-section').style.display = 'none';
                return;
            }
            document.getElementById('wqc-questions-section').style.display = 'block';
            loadWordManagerQuestions(val);
        });
    }

    // 7. Word Question Editor - Add Question Card Click
    const btnWQCAddQuestion = document.getElementById('btn-wqc-add-question');
    if (btnWQCAddQuestion) {
        btnWQCAddQuestion.addEventListener('click', () => {
            addWQCQuestionRow(null, 'UNSCRAMBLE', 'EASY', '', '', '', 100);
        });
    }

    // 8. Word Question Editor - Save All Click
    const btnWQCSaveQuestions = document.getElementById('btn-wqc-save-questions');
    if (btnWQCSaveQuestions) {
        btnWQCSaveQuestions.addEventListener('click', async () => {
            const contestId = parseInt(document.getElementById('wqc-contest-select').value);
            if (isNaN(contestId)) return;

            const qCards = document.getElementById('wqc-questions-list').querySelectorAll('.quiz-question-card');
            const questions = [];

            for (const card of qCards) {
                const gameType = card.querySelector('.wq-game-type').value;
                const difficulty = card.querySelector('.wq-difficulty').value;
                const correctAnswer = card.querySelector('.wq-correct-answer').value.trim();
                const pointsReward = parseInt(card.querySelector('.wq-points-reward').value);
                const clues = card.querySelector('.wq-clues').value.trim();
                const rawPuzzleData = card.querySelector('.wq-puzzle-data').value.trim();

                if (!correctAnswer || isNaN(pointsReward) || !rawPuzzleData) {
                    showToast("Please fill all required fields for all questions.", true);
                    return;
                }

                let parsedPuzzleData;
                try {
                    parsedPuzzleData = JSON.parse(rawPuzzleData);
                } catch (e) {
                    showToast("Puzzle Data is not valid JSON! Error: " + e.message, true);
                    return;
                }

                let parsedClues = clues;
                try {
                    if (clues.startsWith('{') || clues.startsWith('[')) {
                        parsedClues = JSON.parse(clues);
                    }
                } catch (e) {
                    parsedClues = clues;
                }

                questions.push({
                    game_type: gameType,
                    difficulty: difficulty,
                    puzzle_data: parsedPuzzleData,
                    clues: parsedClues,
                    correct_answer: correctAnswer,
                    points_reward: pointsReward
                });
            }

            btnWQCSaveQuestions.disabled = true;
            btnWQCSaveQuestions.innerText = "Saving questions...";

            try {
                const response = await fetch(`${API_BASE}/admin/word-puzzle/questions/bulk/${contestId}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(questions)
                });

                if (!response.ok) throw new Error(await response.text());

                showToast("Word contest questions saved successfully!");
                loadWordManagerQuestions(contestId);
            } catch (err) {
                showToast("Failed to save: " + err.message, true);
            } finally {
                btnWQCSaveQuestions.disabled = false;
                btnWQCSaveQuestions.innerText = "Save All Word Questions";
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
        case 'quiz-manager':
            loadQuizManagerContests();
            break;
        case 'wallet-manager':
            loadWalletManagerUsers();
            break;
        case 'spin-engine':
            loadSpinEngineData();
            break;
        case 'fruit-manager':
            loadFruitManager();
            break;
        case 'puzzle-manager':
            loadPuzzleManager();
            break;
        case 'word-manager':
            loadWordManager();
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
        const endTimeStr = c.end_time ? new Date(c.end_time).toLocaleString() : 'N/A';

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

        let questions = c.questions;
        if (typeof questions === 'string') {
            try {
                questions = JSON.parse(questions);
            } catch (e) {
                questions = [];
            }
        }
        const questionsCount = questions ? questions.length : 0;
        let questionsHtml = '';
        if (questionsCount > 0) {
            const qListHtml = questions.map((q, qIdx) => {
                const optionsHtml = q.options.map((opt, oIdx) => {
                    const isCorrect = oIdx === q.correct_answer_index;
                    return `<li style="color: ${isCorrect ? 'var(--success)' : 'var(--text-muted)'}; font-weight: ${isCorrect ? '600' : 'normal'}; margin-left: 12px; list-style-type: lower-alpha;">${opt} ${isCorrect ? '✓' : ''}</li>`;
                }).join('');
                return `
                    <div style="margin-top: 6px; padding-top: 6px; border-top: 1px dashed rgba(255,255,255,0.05);">
                        <strong style="color: var(--text-main); display: block; margin-bottom: 2px;">Q${qIdx + 1}: ${q.text}</strong>
                        <ol style="margin: 0; padding: 0;">${optionsHtml}</ol>
                    </div>
                `;
            }).join('');

            questionsHtml = `
                <div style="margin-top: 4px;">
                    <button class="btn btn-action" id="toggle-qs-btn-${c.id}" onclick="toggleQuestions(${c.id})" style="padding: 2px 6px; font-size: 10px; background: rgba(255,255,255,0.05); color: var(--text-muted); border: 1px solid var(--border-color);">
                        Show ${questionsCount} Questions
                    </button>
                    <div id="qs-list-${c.id}" data-count="${questionsCount}" style="display: none; margin-top: 8px; padding: 8px; background: rgba(0,0,0,0.2); border-radius: 6px; border: 1px solid var(--border-color); max-width: 320px; text-align: left;">
                        ${qListHtml}
                    </div>
                </div>
            `;
        } else {
            questionsHtml = `<div style="font-size: 11px; color: var(--text-muted); margin-top: 3px; font-style: italic;">📋 No questions added</div>`;
        }

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
                <td>
                    <div style="font-size: 11px;">
                        <div><strong>Start:</strong> ${startTimeStr}</div>
                        <div><strong>End:</strong> ${endTimeStr}</div>
                    </div>
                </td>
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

        // Filter pending manual deposits for approvals table
        const pendingDeposits = allTransactions.filter(t => t.type === 'DEPOSIT' && t.status === 'PENDING');
        renderDepositsTable(pendingDeposits);

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

        let typeBadge = 'badge-warning';
        let typeStyle = 'color: var(--warning)';
        let prefix = '-';

        if (tx.type === 'DEPOSIT' || tx.type === 'PRIZE_WIN' || tx.type === 'REFERRAL_BONUS') {
            typeBadge = 'badge-success';
            typeStyle = 'color: var(--success)';
            prefix = '+';
        } else if (tx.type === 'WITHDRAWAL') {
            typeBadge = 'badge-error';
            typeStyle = 'color: var(--error)';
            prefix = '-';
        } else if (tx.type === 'ENTRY_FEE') {
            typeBadge = 'badge-warning';
            typeStyle = 'color: var(--warning)';
            prefix = '-';
        }

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

function renderDepositsTable(depositsList) {
    if (!el.depositsTable) return;

    if (depositsList.length === 0) {
        el.depositsTable.innerHTML = `<tr><td colspan="6" class="table-placeholder">No pending manual deposits.</td></tr>`;
        return;
    }

    el.depositsTable.innerHTML = depositsList.map(d => {
        const dateStr = new Date(d.created_at).toLocaleString();
        const userObj = state.users.find(u => u.id === d.user_id);
        const userDetails = userObj ? `${userObj.name || 'Anonymous'} (${userObj.phone})` : `User #${d.user_id}`;

        let actions = `
            <div style="display:flex; gap: 8px;">
                <button class="btn btn-action btn-unban" onclick="approveDeposit(${d.id}, true)">Approve</button>
                <button class="btn btn-action btn-ban" onclick="approveDeposit(${d.id}, false)">Reject</button>
            </div>
        `;

        return `
            <tr>
                <td>#${d.id}</td>
                <td>${userDetails}</td>
                <td><strong style="color:var(--success)">₹${d.amount.toFixed(2)}</strong></td>
                <td><code style="background: rgba(255,255,255,0.05); padding: 4px 8px; border-radius: 4px; font-family: monospace; font-size: 12px; color: var(--primary);">${d.utr || 'N/A'}</code></td>
                <td>${dateStr}</td>
                <td>${actions}</td>
            </tr>
        `;
    }).join('');
}

async function approveDeposit(txId, approve) {
    try {
        const res = await fetch(`${API_BASE}/admin/deposits/${txId}/approve?approve=${approve}`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error("Failed to process deposit action.");

        showToast(approve ? "Manual deposit approved and credited!" : "Manual deposit request rejected.");
        loadDashboardData();
    } catch (err) {
        showToast(err.message, true);
    }
}

window.approveDeposit = approveDeposit;

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

window.toggleQuestions = function (contestId) {
    const listEl = document.getElementById(`qs-list-${contestId}`);
    const btnEl = document.getElementById(`toggle-qs-btn-${contestId}`);
    if (listEl && btnEl) {
        if (listEl.style.display === 'none') {
            listEl.style.display = 'block';
            btnEl.innerText = 'Hide Questions';
        } else {
            listEl.style.display = 'none';
            const count = listEl.dataset.count || 'Questions';
            btnEl.innerText = `Show ${count} Questions`;
        }
    }
}

// Quiz Manager Actions and Helpers
async function loadQuizManagerContests() {
    try {
        const res = await fetch(`${API_BASE}/contests`);
        if (!res.ok) throw new Error("Failed to load contests.");
        const contests = await res.json();

        const select = document.getElementById('qm-contest-select');
        select.innerHTML = '<option value="">-- Choose a Contest --</option>' +
            contests.map(c => `<option value="${c.id}">${c.title} (ID: ${c.id})</option>`).join('');

        // Reset view
        document.getElementById('qm-questions-section').style.display = 'none';
        document.getElementById('qm-questions-list').innerHTML = '';

        // Save current contests in memory
        state.contests = contests;
    } catch (err) {
        showToast(err.message, true);
    }
}

function addQMQuestionRow(text = '', options = ['', '', '', ''], correctIndex = 0) {
    const listContainer = document.getElementById('qm-questions-list');
    const card = document.createElement('div');
    card.className = 'quiz-question-card';
    card.innerHTML = `
        <div class="question-header">
            <input type="text" placeholder="Question Text" class="q-text" value="${text.replace(/"/g, '&quot;')}" required style="width: 100%;">
            <button type="button" class="btn-remove-rule btn-remove-question" title="Remove Question" style="margin-left: 10px;">&times;</button>
        </div>
        <div class="question-options-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 10px;">
            <input type="text" placeholder="Option A" class="q-opt-0" value="${options[0].replace(/"/g, '&quot;')}" required>
            <input type="text" placeholder="Option B" class="q-opt-1" value="${options[1].replace(/"/g, '&quot;')}" required>
            <input type="text" placeholder="Option C" class="q-opt-2" value="${options[2].replace(/"/g, '&quot;')}" required>
            <input type="text" placeholder="Option D" class="q-opt-3" value="${options[3].replace(/"/g, '&quot;')}" required>
        </div>
        <div class="question-footer" style="margin-top: 10px; display: flex; align-items: center; gap: 10px;">
            <span style="font-size:12px; color:var(--text-muted);">Correct Answer:</span>
            <select class="q-correct" style="background: #1e293b; color: #fff; border: 1px solid #334155; padding: 6px 12px; border-radius: 6px; font-family: inherit;">
                <option value="0" ${correctIndex === 0 ? 'selected' : ''}>Option A</option>
                <option value="1" ${correctIndex === 1 ? 'selected' : ''}>Option B</option>
                <option value="2" ${correctIndex === 2 ? 'selected' : ''}>Option C</option>
                <option value="3" ${correctIndex === 3 ? 'selected' : ''}>Option D</option>
            </select>
        </div>
    `;

    card.querySelector('.btn-remove-question').addEventListener('click', () => {
        card.remove();
    });

    listContainer.appendChild(card);
}

// Setup Event Listeners for Quiz Manager elements
document.addEventListener('DOMContentLoaded', () => {
    const qmSelect = document.getElementById('qm-contest-select');
    if (qmSelect) {
        qmSelect.addEventListener('change', (e) => {
            const contestId = parseInt(e.target.value);
            if (isNaN(contestId)) {
                document.getElementById('qm-questions-section').style.display = 'none';
                return;
            }

            const contest = state.contests.find(c => c.id === contestId);
            if (!contest) return;

            document.getElementById('qm-questions-section').style.display = 'block';
            const listContainer = document.getElementById('qm-questions-list');
            listContainer.innerHTML = '';

            let questions = contest.questions;
            if (typeof questions === 'string') {
                try {
                    questions = JSON.parse(questions);
                } catch (e) {
                    questions = [];
                }
            }

            if (questions && questions.length > 0) {
                questions.forEach(q => addQMQuestionRow(q.text, q.options, q.correct_answer_index));
            } else {
                addQMQuestionRow('', ['', '', '', ''], 0);
            }
        });
    }

    const btnQMAddQuestion = document.getElementById('btn-qm-add-question');
    if (btnQMAddQuestion) {
        btnQMAddQuestion.addEventListener('click', () => {
            addQMQuestionRow('', ['', '', '', ''], 0);
        });
    }

    const btnQMSaveQuestions = document.getElementById('btn-qm-save-questions');
    if (btnQMSaveQuestions) {
        btnQMSaveQuestions.addEventListener('click', async () => {
            const contestId = parseInt(document.getElementById('qm-contest-select').value);
            if (isNaN(contestId)) return;

            const qCards = document.getElementById('qm-questions-list').querySelectorAll('.quiz-question-card');
            const questions = [];

            for (const card of qCards) {
                const text = card.querySelector('.q-text').value.trim();
                const opt0 = card.querySelector('.q-opt-0').value.trim();
                const opt1 = card.querySelector('.q-opt-1').value.trim();
                const opt2 = card.querySelector('.q-opt-2').value.trim();
                const opt3 = card.querySelector('.q-opt-3').value.trim();
                const correctAnswerIndex = parseInt(card.querySelector('.q-correct').value);

                if (!text || !opt0 || !opt1 || !opt2 || !opt3 || isNaN(correctAnswerIndex)) {
                    showToast("Please fill all fields for all questions.", true);
                    return;
                }

                questions.push({
                    text: text,
                    options: [opt0, opt1, opt2, opt3],
                    correct_answer_index: correctAnswerIndex
                });
            }

            btnQMSaveQuestions.disabled = true;
            btnQMSaveQuestions.innerText = "Saving...";

            try {
                const response = await fetch(`${API_BASE}/admin/contests/${contestId}/questions`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(questions)
                });

                if (!response.ok) throw new Error(await response.text());

                showToast("Contest questions updated successfully!");
                loadQuizManagerContests().then(() => {
                    document.getElementById('qm-contest-select').value = contestId;
                    document.getElementById('qm-contest-select').dispatchEvent(new Event('change'));
                });
            } catch (err) {
                console.error(err);
                showToast("Failed to save questions: " + err.message, true);
            } finally {
                btnQMSaveQuestions.disabled = false;
                btnQMSaveQuestions.innerText = "Save All Questions";
            }
        });
    }
});

// Wallet Manager Actions and Helpers
async function loadWalletManagerUsers() {
    try {
        const res = await fetch(`${API_BASE}/admin/users`);
        if (!res.ok) throw new Error("Failed to load users list.");
        const users = await res.json();

        const select = document.getElementById('wm-user-select');
        select.innerHTML = '<option value="">-- Choose User --</option>' +
            users.map(u => `<option value="${u.id}">${u.name || 'Anonymous'} (${u.phone}) - ID: ${u.id}</option>`).join('');

        // Reset view
        document.getElementById('wm-user-balances').style.display = 'none';
        document.getElementById('wm-amount').value = '';

        // Save current users in memory
        state.users = users;
    } catch (err) {
        showToast(err.message, true);
    }
}

// Setup Event Listeners for Wallet Manager elements
document.addEventListener('DOMContentLoaded', () => {
    const wmUserSelect = document.getElementById('wm-user-select');
    if (wmUserSelect) {
        wmUserSelect.addEventListener('change', (e) => {
            const userId = parseInt(e.target.value);
            if (isNaN(userId)) {
                document.getElementById('wm-user-balances').style.display = 'none';
                return;
            }

            const user = state.users.find(u => u.id === userId);
            if (!user) return;

            document.getElementById('wm-user-balances').style.display = 'block';
            document.getElementById('wm-val-dep').innerText = `₹${user.deposit_balance.toFixed(2)}`;
            document.getElementById('wm-val-win').innerText = `₹${user.winning_balance.toFixed(2)}`;
            document.getElementById('wm-val-bon').innerText = `₹${user.bonus_balance.toFixed(2)}`;
        });
    }

    const wmAdjustForm = document.getElementById('wm-adjust-balance-form');
    if (wmAdjustForm) {
        wmAdjustForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const userId = parseInt(document.getElementById('wm-user-select').value);
            const walletType = document.getElementById('wm-wallet-type').value;
            const amount = parseFloat(document.getElementById('wm-amount').value);

            if (isNaN(userId) || isNaN(amount)) {
                showToast("Please select a user and enter a valid amount.", true);
                return;
            }

            const btnSubmit = wmAdjustForm.querySelector('button[type="submit"]');
            btnSubmit.disabled = true;
            btnSubmit.innerText = "Updating...";

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
                loadWalletManagerUsers().then(() => {
                    document.getElementById('wm-user-select').value = userId;
                    document.getElementById('wm-user-select').dispatchEvent(new Event('change'));
                });
            } catch (err) {
                console.error(err);
                showToast("Failed to adjust balance: " + err.message, true);
            } finally {
                btnSubmit.disabled = false;
                btnSubmit.innerText = "Submit Balance Update";
            }
        });
    }
});


// ==========================================
// CASINO SPIN WHEEL ENGINE ADMINISTRATIVE CONTROLLERS
// ==========================================

// Global state variables for spin settings
state.rtp_settings = [];
state.maintenance_active = false;

async function loadSpinEngineData() {
    try {
        // 1. Fetch spin metrics/stats
        const statsRes = await fetch(`${API_BASE}/admin/spin/stats`);
        if (statsRes.ok) {
            const stats = await statsRes.json();
            document.getElementById('spin-stat-bets').innerText = `₹${stats.total_bet_amount.toFixed(2)}`;
            document.getElementById('spin-stat-winnings').innerText = `₹${stats.total_winnings_paid.toFixed(2)}`;
            document.getElementById('spin-stat-profit').innerText = `₹${stats.platform_net_profit.toFixed(2)}`;
            document.getElementById('spin-stat-rtp').innerText = `${stats.payout_ratio.toFixed(2)}%`;

            const profitEl = document.getElementById('spin-stat-profit');
            if (stats.platform_net_profit < 0) {
                profitEl.style.color = 'var(--error)';
            } else {
                profitEl.style.color = 'var(--success)';
            }
        }

        // 2. Fetch maintenance lockout status
        const maintenanceRes = await fetch(`${API_BASE}/admin/maintenance`);
        if (maintenanceRes.ok) {
            const m = await maintenanceRes.json();
            state.maintenance_active = m.maintenance_mode;
            const btn = document.getElementById('btn-toggle-maintenance');
            if (btn) {
                btn.innerText = state.maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.maintenance_active ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

        // 3. Fetch RTP configurations
        await loadRtpSettings();

        // 4. Fetch suspicious users
        await loadSuspiciousUsers();

        // 5. Fetch live spin audit logs
        await loadSpinLogs();

    } catch (err) {
        console.error(err);
        showToast("Error updating Spin Engine dashboard: " + err.message, true);
    }
}

async function loadRtpSettings() {
    try {
        const res = await fetch(`${API_BASE}/admin/rtp`);
        if (!res.ok) throw new Error("Failed to load RTP data.");
        state.rtp_settings = await res.json();

        // Update JSON editor with currently selected tier range
        const tierSelect = document.getElementById('rtp-tier-select');
        if (tierSelect) {
            const tierVal = parseInt(tierSelect.value) || 1;
            const setting = state.rtp_settings.find(r => r.id === tierVal);
            if (setting) {
                // Pretty print JSON
                try {
                    const parsed = JSON.parse(setting.probability_json);
                    document.getElementById('rtp-json-editor').value = JSON.stringify(parsed, null, 4);
                } catch (_) {
                    document.getElementById('rtp-json-editor').value = setting.probability_json;
                }
            }
        }
    } catch (err) {
        console.error(err);
    }
}

async function loadSuspiciousUsers() {
    try {
        const res = await fetch(`${API_BASE}/admin/suspicious-users`);
        if (!res.ok) throw new Error("Failed to load suspicious users.");
        const list = await res.json();

        const tbody = document.getElementById('suspicious-spins-table-body');
        if (!tbody) return;

        if (list.length === 0) {
            tbody.innerHTML = `<tr><td colspan="4" class="table-placeholder">No suspicious activity detected.</td></tr>`;
            return;
        }

        tbody.innerHTML = list.map(u => {
            const netProfit = u.total_win - u.total_bet;
            return `
                <tr>
                    <td>
                        <strong style="color:var(--text-main);">${u.name || 'Anonymous'}</strong>
                        <span class="text-muted" style="display:block; font-size:10px;">${u.phone} (ID: ${u.user_id})</span>
                    </td>
                    <td>${u.total_spins}</td>
                    <td>
                        <strong style="color:${u.win_ratio > 65.0 ? 'var(--error)' : 'var(--text-muted)'}">${u.win_ratio.toFixed(1)}%</strong>
                    </td>
                    <td>
                        <strong style="color:${netProfit > 0 ? 'var(--success)' : 'var(--text-muted)'}">₹${netProfit.toFixed(2)}</strong>
                    </td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
    }
}

async function loadSpinLogs() {
    try {
        const res = await fetch(`${API_BASE}/admin/spin/logs`);
        if (!res.ok) throw new Error("Failed to load spin logs.");
        const logs = await res.json();

        const tbody = document.getElementById('spin-logs-table-body');
        if (!tbody) return;

        if (logs.length === 0) {
            tbody.innerHTML = `<tr><td colspan="7" class="table-placeholder">No spins logged yet.</td></tr>`;
            return;
        }

        tbody.innerHTML = logs.map(s => {
            const dateStr = new Date(s.created_at).toLocaleString();
            const winStyle = s.win_amount > 0 ? 'color: var(--success)' : 'color: var(--text-muted)';
            const sign = s.win_amount > 0 ? '+' : '';
            return `
                <tr>
                    <td>#${s.id}</td>
                    <td><strong>${s.user_phone}</strong></td>
                    <td>₹${s.bet_amount.toFixed(2)}</td>
                    <td><span class="badge ${s.win_amount > 0 ? 'badge-success' : 'badge-warning'}">${s.multiplier}x</span></td>
                    <td><strong style="${winStyle}">${sign}₹${s.win_amount.toFixed(2)}</strong></td>
                    <td><span class="badge badge-info">${s.wheel_segment}</span></td>
                    <td>${dateStr}</td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
    }
}

// Add DOM Listeners for Spin Engine Tab Elements
document.addEventListener('DOMContentLoaded', () => {
    // 1. Bet range select dropdown listener
    const tierSelect = document.getElementById('rtp-tier-select');
    if (tierSelect) {
        tierSelect.addEventListener('change', (e) => {
            const tierVal = parseInt(e.target.value);
            const setting = state.rtp_settings.find(r => r.id === tierVal);
            if (setting) {
                try {
                    const parsed = JSON.parse(setting.probability_json);
                    document.getElementById('rtp-json-editor').value = JSON.stringify(parsed, null, 4);
                } catch (_) {
                    document.getElementById('rtp-json-editor').value = setting.probability_json;
                }
            }
        });
    }

    // 2. RTP JSON Config Form Submission
    const rtpForm = document.getElementById('spin-rtp-admin-form');
    if (rtpForm) {
        rtpForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const tierId = parseInt(document.getElementById('rtp-tier-select').value);
            const rawJson = document.getElementById('rtp-json-editor').value.trim();

            if (isNaN(tierId) || !rawJson) return;

            const btn = rtpForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Saving settings...";

            try {
                // Double check JSON syntax on client
                const parsed = JSON.parse(rawJson);
                const sum = Object.values(parsed).reduce((a, b) => a + b, 0);
                if (Math.abs(sum - 100) > 1.0) {
                    throw new Error(`Total probability weights must sum to exactly 100%. (Current sum: ${sum}%)`);
                }

                const response = await fetch(`${API_BASE}/admin/rtp/${tierId}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        probability_json: JSON.stringify(parsed),
                        enabled: true
                    })
                });

                if (!response.ok) {
                    const errText = await response.text();
                    throw new Error(errText || "Failed to save settings.");
                }

                showToast("RTP configuration saved and live on production!");
                loadSpinEngineData();
            } catch (err) {
                console.error(err);
                showToast("RTP configuration error: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Save RTP Settings";
            }
        });
    }

    // 3. Maintenance Toggle Button
    const btnToggleMaintenance = document.getElementById('btn-toggle-maintenance');
    if (btnToggleMaintenance) {
        btnToggleMaintenance.addEventListener('click', async () => {
            const nextMode = !state.maintenance_active;
            btnToggleMaintenance.disabled = true;

            try {
                const res = await fetch(`${API_BASE}/admin/maintenance?enabled=${nextMode}`, {
                    method: 'POST'
                });
                if (!res.ok) throw new Error("Failed to change maintenance status.");

                state.maintenance_active = nextMode;
                btnToggleMaintenance.innerText = state.maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btnToggleMaintenance.style.backgroundColor = state.maintenance_active ? 'var(--success)' : 'var(--error)';
                showToast(state.maintenance_active ? "Spin Wheel has been LOCKED for maintenance." : "Spin Wheel unlocked! Game access is live.");
            } catch (err) {
                showToast("Maintenance toggle error: " + err.message, true);
            } finally {
                btnToggleMaintenance.disabled = false;
            }
        });
    }
});


// ==========================================
// FRUIT SLICING TOURNAMENT MANAGER CONTROLLER
// ==========================================

async function loadFruitManager() {
    try {
        const res = await fetch(`${API_BASE}/fruit-game/contests`);
        if (!res.ok) throw new Error("Failed to load Fruit Slicing contests.");
        const contests = await res.json();

        // 1. Calculate and update stats
        const activeCount = contests.filter(c => c.status === 'ACTIVE').length;
        const totalFees = contests.reduce((sum, c) => sum + (c.entry_fee * c.joined_slots), 0);

        document.getElementById('fruit-stat-active').innerText = activeCount;
        document.getElementById('fruit-stat-fees').innerText = `₹${totalFees.toFixed(2)}`;

        // 2. Render table
        const tbody = document.getElementById('fruit-contests-table-body');
        if (tbody) {
            if (contests.length === 0) {
                tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder">No Fruit Slicing contests active or defined yet.</td></tr>`;
                return;
            }

            tbody.innerHTML = contests.map(c => {
                let statusBadge = 'badge-warning';
                if (c.status === 'ACTIVE') statusBadge = 'badge-success';
                if (c.status === 'COMPLETED') statusBadge = 'badge-info';

                const startTimeStr = new Date(c.start_time).toLocaleString();
                const endTimeStr = c.end_time ? new Date(c.end_time).toLocaleString() : 'N/A';

                const actionBtn = c.status !== 'COMPLETED'
                    ? `<button class="btn btn-action btn-unban" onclick="completeFruitContest(${c.id})">Complete</button>`
                    : `<span class="text-muted" style="font-size:12px;">Payout Done</span>`;

                let rulesHtml = '';
                if (c.prize_rules && c.prize_rules.length > 0) {
                    rulesHtml = `<div style="font-size: 11px; color: var(--text-muted); margin-top: 5px; display: flex; flex-direction: column; gap: 2px;">` +
                        c.prize_rules.map(r => `<span>Rank ${r.min_rank}${r.min_rank === r.max_rank ? '' : '-' + r.max_rank}: ₹${r.prize}</span>`).join('') +
                        `</div>`;
                }

                return `
                    <tr>
                        <td>${c.id}</td>
                        <td>
                            <strong style="font-size:14px; color:var(--text-main);">${c.title}</strong>
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
                        <td>
                            <div style="font-size: 11px;">
                                <div><strong>Start:</strong> ${startTimeStr}</div>
                                <div><strong>End:</strong> ${endTimeStr}</div>
                                <div><strong>Duration:</strong> ${c.duration_seconds}s</div>
                                <div><strong>Seed:</strong> <code style="color:var(--warning);">${c.seed}</code></div>
                            </div>
                        </td>
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
    } catch (err) {
        showToast(err.message, true);
        const tbody = document.getElementById('fruit-contests-table-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder" style="color: var(--error);">Failed to load Fruit Slicing contests: ${err.message}</td></tr>`;
        }
    }
}

async function completeFruitContest(contestId) {
    if (!confirm("Are you sure you want to complete this Fruit contest and award the winners?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/fruit-slicing/contests/${contestId}/complete`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Fruit tournament completed and prize payouts distributed!");
        loadFruitManager();
    } catch (err) {
        showToast("Error completing Fruit tournament: " + err.message, true);
    }
}

window.completeFruitContest = completeFruitContest;


// ==========================================
// IMAGE SLIDE PUZZLE MANAGER CONTROLLER
// ==========================================

async function loadPuzzleManager() {
    try {
        const res = await fetch(`${API_BASE}/puzzle/contests`);
        if (!res.ok) throw new Error("Failed to load Image Puzzle contests.");
        const contests = await res.json();

        // 1. Calculate and update stats
        const activeCount = contests.filter(c => c.status === 'ACTIVE').length;
        document.getElementById('puzzle-stat-active').innerText = activeCount;

        // 2. Render table
        const tbody = document.getElementById('puzzle-contests-table-body');
        if (tbody) {
            if (contests.length === 0) {
                tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder">No Image Puzzle contests active or defined yet.</td></tr>`;
                return;
            }

            tbody.innerHTML = contests.map(c => {
                let statusBadge = 'badge-warning';
                if (c.status === 'ACTIVE') statusBadge = 'badge-success';
                if (c.status === 'COMPLETED') statusBadge = 'badge-info';

                const startTimeStr = new Date(c.start_time).toLocaleString();
                const endTimeStr = c.end_time ? new Date(c.end_time).toLocaleString() : 'N/A';

                const actionBtn = c.status !== 'COMPLETED'
                    ? `<button class="btn btn-action btn-unban" onclick="completePuzzleContest(${c.id})">Complete</button>`
                    : `<span class="text-muted" style="font-size:12px;">Payout Done</span>`;

                let rulesHtml = '';
                if (c.prize_rules && c.prize_rules.length > 0) {
                    rulesHtml = `<div style="font-size: 11px; color: var(--text-muted); margin-top: 5px; display: flex; flex-direction: column; gap: 2px;">` +
                        c.prize_rules.map(r => `<span>Rank ${r.min_rank}${r.min_rank === r.max_rank ? '' : '-' + r.max_rank}: ₹${r.prize}</span>`).join('') +
                        `</div>`;
                }

                return `
                    <tr>
                        <td>${c.id}</td>
                        <td>
                            <div style="display:flex; gap:10px; align-items:center;">
                                <img src="${c.image_url}" style="width:40px; height:40px; border-radius:6px; border:1px solid var(--border-color); object-fit:cover;">
                                <strong style="font-size:14px; color:var(--text-main);">${c.title}</strong>
                            </div>
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
                        <td>
                            <div style="font-size: 11px;">
                                <div><strong>Grid Size:</strong> ${c.grid_size}x${c.grid_size}</div>
                                <div><strong>Solve Limit:</strong> ${c.duration_seconds}s</div>
                                <div><strong>Start:</strong> ${startTimeStr}</div>
                                <div><strong>End:</strong> ${endTimeStr}</div>
                            </div>
                        </td>
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
    } catch (err) {
        showToast(err.message, true);
        const tbody = document.getElementById('puzzle-contests-table-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder" style="color: var(--error);">Failed to load Image Puzzle contests: ${err.message}</td></tr>`;
        }
    }
}

async function completePuzzleContest(contestId) {
    if (!confirm("Are you sure you want to complete this Image Puzzle contest and award the winners?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/puzzle/contests/${contestId}/complete`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Puzzle contest completed and prize payouts distributed!");
        loadPuzzleManager();
    } catch (err) {
        showToast("Error completing Puzzle contest: " + err.message, true);
    }
}

window.completePuzzleContest = completePuzzleContest;


// ==========================================
// WORD PUZZLE MANAGER CONTROLLER
// ==========================================

// Word Questions templates based on Game Type
const WORD_PUZZLE_TEMPLATES = {
    UNSCRAMBLE: { scrambled: "DART" },
    MISSING_LETTERS: { pattern: "D_R_" },
    WORD_SEARCH: { grid: [["B", "L", "O", "C"], ["X", "Y", "Z", "A"], ["Q", "W", "E", "R"], ["A", "S", "D", "F"]] },
    CROSSWORD: { grid: [["D", "A", "R", "T"]], row: 0, col: 0, direction: "horizontal" }
};

async function loadWordManager() {
    try {
        const res = await fetch(`${API_BASE}/word-game/contests`);
        if (!res.ok) throw new Error("Failed to load Word Guessing contests.");
        const contests = await res.json();

        // 1. Calculate and update stats
        const activeCount = contests.filter(c => c.status === 'ACTIVE').length;
        document.getElementById('word-stat-active').innerText = activeCount;

        // 2. Populate contest select for question editor
        const select = document.getElementById('wqc-contest-select');
        if (select) {
            select.innerHTML = '<option value="">-- Choose a Word Contest --</option>' +
                contests.map(c => `<option value="${c.id}">${c.title} (ID: ${c.id})</option>`).join('');

            // Reset view
            document.getElementById('wqc-questions-section').style.display = 'none';
            document.getElementById('wqc-questions-list').innerHTML = '';
        }

        // 3. Render table
        const tbody = document.getElementById('word-contests-table-body');
        if (tbody) {
            if (contests.length === 0) {
                tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder">No Word Guessing contests active or defined yet.</td></tr>`;
                return;
            }

            tbody.innerHTML = contests.map(c => {
                let statusBadge = 'badge-warning';
                if (c.status === 'ACTIVE') statusBadge = 'badge-success';
                if (c.status === 'COMPLETED') statusBadge = 'badge-info';

                const startTimeStr = new Date(c.start_time).toLocaleString();
                const endTimeStr = c.end_time ? new Date(c.end_time).toLocaleString() : 'N/A';

                const actionBtn = c.status !== 'COMPLETED'
                    ? `<button class="btn btn-action btn-unban" onclick="completeWordContest(${c.id})">Complete</button>`
                    : `<span class="text-muted" style="font-size:12px;">Payout Done</span>`;

                let rulesHtml = '';
                if (c.prize_rules && c.prize_rules.length > 0) {
                    rulesHtml = `<div style="font-size: 11px; color: var(--text-muted); margin-top: 5px; display: flex; flex-direction: column; gap: 2px;">` +
                        c.prize_rules.map(r => `<span>Rank ${r.min_rank}${r.min_rank === r.max_rank ? '' : '-' + r.max_rank}: ₹${r.prize}</span>`).join('') +
                        `</div>`;
                }

                return `
                    <tr>
                        <td>${c.id}</td>
                        <td>
                            <strong style="font-size:14px; color:var(--text-main);">${c.title}</strong>
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
                        <td>
                            <div style="font-size: 11px;">
                                <div><strong>Difficulty:</strong> <span class="badge badge-info">${c.difficulty}</span></div>
                                <div><strong>Solve Limit:</strong> ${c.duration_seconds}s</div>
                                <div><strong>Start:</strong> ${startTimeStr}</div>
                                <div><strong>End:</strong> ${endTimeStr}</div>
                            </div>
                        </td>
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
    } catch (err) {
        showToast(err.message, true);
        const tbody = document.getElementById('word-contests-table-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder" style="color: var(--error);">Failed to load Word Guessing contests: ${err.message}</td></tr>`;
        }
    }
}

async function completeWordContest(contestId) {
    if (!confirm("Are you sure you want to complete this Word contest and award the winners?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/word-puzzle/contests/${contestId}/complete`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Word contest completed and prize payouts distributed!");
        loadWordManager();
    } catch (err) {
        showToast("Error completing Word contest: " + err.message, true);
    }
}

window.completeWordContest = completeWordContest;

async function loadWordManagerQuestions(contestId) {
    try {
        const res = await fetch(`${API_BASE}/admin/word-puzzle/contests/${contestId}/questions`);
        if (!res.ok) throw new Error("Failed to load word questions.");
        const questions = await res.json();

        const listContainer = document.getElementById('wqc-questions-list');
        listContainer.innerHTML = '';

        if (questions && questions.length > 0) {
            questions.forEach(q => {
                addWQCQuestionRow(q.id, q.game_type, q.difficulty, q.puzzle_data, q.clues, q.correct_answer, q.points_reward);
            });
        } else {
            addWQCQuestionRow(null, 'UNSCRAMBLE', 'EASY', '', '', '', 100);
        }
    } catch (err) {
        showToast(err.message, true);
    }
}

function addWQCQuestionRow(id = null, gameType = 'UNSCRAMBLE', difficulty = 'EASY', puzzleData = '', clues = '', correctAnswer = '', pointsReward = 100) {
    const listContainer = document.getElementById('wqc-questions-list');
    if (!listContainer) return;

    const card = document.createElement('div');
    card.className = 'quiz-question-card';

    let puzzleDataStr = typeof puzzleData === 'object' ? JSON.stringify(puzzleData, null, 4) : puzzleData;
    let cluesStr = typeof clues === 'object' ? JSON.stringify(clues) : clues || '';

    card.innerHTML = `
        <div class="question-header">
            <span style="font-size:12px; color:var(--primary); font-weight:700;">Word Question</span>
            <button type="button" class="btn-remove-rule btn-remove-question" title="Remove Question">&times;</button>
        </div>
        <div class="question-options-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 10px;">
            <div class="form-group">
                <label>Game Type</label>
                <select class="wq-game-type" style="background: #1e293b; color: #fff; border: 1px solid #334155; padding: 8px 12px; border-radius: 6px; font-family: inherit; font-size:12px;">
                    <option value="UNSCRAMBLE" ${gameType === 'UNSCRAMBLE' ? 'selected' : ''}>UNSCRAMBLE</option>
                    <option value="MISSING_LETTERS" ${gameType === 'MISSING_LETTERS' ? 'selected' : ''}>MISSING_LETTERS</option>
                    <option value="WORD_SEARCH" ${gameType === 'WORD_SEARCH' ? 'selected' : ''}>WORD_SEARCH</option>
                    <option value="CROSSWORD" ${gameType === 'CROSSWORD' ? 'selected' : ''}>CROSSWORD</option>
                </select>
            </div>
            <div class="form-group">
                <label>Difficulty</label>
                <select class="wq-difficulty" style="background: #1e293b; color: #fff; border: 1px solid #334155; padding: 8px 12px; border-radius: 6px; font-family: inherit; font-size:12px;">
                    <option value="EASY" ${difficulty === 'EASY' ? 'selected' : ''}>EASY</option>
                    <option value="MEDIUM" ${difficulty === 'MEDIUM' ? 'selected' : ''}>MEDIUM</option>
                    <option value="HARD" ${difficulty === 'HARD' ? 'selected' : ''}>HARD</option>
                </select>
            </div>
        </div>
        
        <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-top:10px;">
            <div class="form-group">
                <label>Correct Answer</label>
                <input type="text" class="wq-correct-answer" value="${correctAnswer.replace(/"/g, '&quot;')}" placeholder="e.g. DART" required>
            </div>
            <div class="form-group">
                <label>Points Reward</label>
                <input type="number" class="wq-points-reward" value="${pointsReward}" min="1" required>
            </div>
        </div>

        <div class="form-group" style="margin-top:10px;">
            <label>Clues / Hint</label>
            <input type="text" class="wq-clues" value="${cluesStr.replace(/"/g, '&quot;')}" placeholder="e.g. Target language for Flutter apps.">
        </div>

        <div class="form-group" style="margin-top:10px;">
            <label>Puzzle Data (JSON format)</label>
            <textarea class="wq-puzzle-data" style="width:100%; height:80px; background:#1e293b; color:#51ff00; border:1px solid #334155; padding:10px; border-radius:6px; font-family: monospace; resize:none; font-size:11px; line-height: 1.4;" required>${puzzleDataStr}</textarea>
            <span class="template-help-text" style="font-size: 10px; color: var(--text-muted); display: block; margin-top: 4px;"></span>
        </div>
    `;

    const typeSelect = card.querySelector('.wq-game-type');
    const puzzleDataArea = card.querySelector('.wq-puzzle-data');
    const helpTextSpan = card.querySelector('.template-help-text');

    const updateHelpText = () => {
        const type = typeSelect.value;
        if (type === 'UNSCRAMBLE') {
            helpTextSpan.innerHTML = `Format: <code>{"scrambled": "TDAR"}</code>`;
        } else if (type === 'MISSING_LETTERS') {
            helpTextSpan.innerHTML = `Format: <code>{"pattern": "D_R_"}</code>`;
        } else if (type === 'WORD_SEARCH') {
            helpTextSpan.innerHTML = `Format: <code>{"grid": [["B","L","O","C"], ["X","Y","Z","A"], ...]}</code>`;
        } else if (type === 'CROSSWORD') {
            helpTextSpan.innerHTML = `Format: <code>{"grid": [["D","A","R","T"]], "row": 0, "col": 0, "direction": "horizontal"}</code>`;
        }
    };

    typeSelect.addEventListener('change', () => {
        updateHelpText();
        const type = typeSelect.value;
        if (!puzzleDataArea.value || puzzleDataArea.value === '{}' || puzzleDataArea.value.includes('"scrambled"') || puzzleDataArea.value.includes('"pattern"') || puzzleDataArea.value.includes('"grid"')) {
            puzzleDataArea.value = JSON.stringify(WORD_PUZZLE_TEMPLATES[type], null, 4);
        }
    });

    card.querySelector('.btn-remove-question').addEventListener('click', () => {
        card.remove();
    });

    updateHelpText();
    if (!puzzleDataStr) {
        puzzleDataArea.value = JSON.stringify(WORD_PUZZLE_TEMPLATES[gameType], null, 4);
    }

    listContainer.appendChild(card);
}

function addPrizeRuleRow(listContainerId) {
    console.log("addPrizeRuleRow called for:", listContainerId);
    const listEl = document.getElementById(listContainerId);
    if (!listEl) {
        console.error("List container element not found:", listContainerId);
        return;
    }
    const rows = listEl.querySelectorAll('.prize-rule-row');
    let nextMin = 1;
    if (rows.length > 0) {
        const lastMaxInput = rows[rows.length - 1].querySelector('.rule-max-rank');
        if (lastMaxInput) {
            const lastMax = parseInt(lastMaxInput.value);
            if (!isNaN(lastMax)) {
                nextMin = lastMax + 1;
            }
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
    if (minInput && maxInput) {
        minInput.addEventListener('input', () => {
            if (maxInput.value === minInput.dataset.prevMin || maxInput.value === '') {
                maxInput.value = minInput.value;
            }
            minInput.dataset.prevMin = minInput.value;
        });
        minInput.dataset.prevMin = minInput.value;
    }

    listEl.appendChild(row);
    listEl.scrollTop = listEl.scrollHeight;
    console.log("Successfully appended new prize rule row to", listContainerId);
}






