// Configuration
const API_BASE = '/api';

// State management
let state = {
    activeTab: 'overview',
    users: [],
    contests: [],
    withdrawals: [],
    transactions: [],
    fruit_maintenance_active: false,
    puzzle_maintenance_active: false,
    word_maintenance_active: false,
    arrow_maintenance_active: false,
    quiz_maintenance_active: false
};

// Global originalFetch Proxy to secure all API requests
const originalFetch = window.fetch;
window.fetch = async function (resource, init = {}) {
    const token = localStorage.getItem('adminToken');
    if (token && typeof resource === 'string' && resource.startsWith(API_BASE)) {
        init.headers = init.headers || {};
        if (init.headers instanceof Headers) {
            if (!init.headers.has('Authorization')) {
                init.headers.set('Authorization', `Bearer ${token}`);
            }
        } else {
            if (!init.headers['Authorization'] && !init.headers['authorization']) {
                init.headers['Authorization'] = `Bearer ${token}`;
            }
        }
    }

    try {
        const response = await originalFetch(resource, init);
        if (response.status === 401 && typeof resource === 'string' && resource.startsWith(API_BASE)) {
            if (!resource.includes('/admin/login')) {
                handleUnauthorized();
            }
        }
        return response;
    } catch (error) {
        throw error;
    }
};

function handleUnauthorized() {
    localStorage.removeItem('adminToken');
    const appContainer = document.querySelector('.app-container');
    if (appContainer) {
        appContainer.style.display = 'none';
    }
    const loginOverlay = document.getElementById('admin-login-overlay');
    if (loginOverlay) {
        loginOverlay.classList.remove('hidden');
    }
}

async function handleAdminLogin(username, password) {
    const errorEl = document.getElementById('login-error');
    errorEl.style.display = 'none';

    try {
        const response = await originalFetch(`${API_BASE}/admin/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });

        if (!response.ok) {
            throw new Error("Invalid username or password");
        }

        const data = await response.json();
        localStorage.setItem('adminToken', data.access_token);

        const appContainer = document.querySelector('.app-container');
        if (appContainer) {
            appContainer.style.display = 'flex';
        }
        const loginOverlay = document.getElementById('admin-login-overlay');
        if (loginOverlay) {
            loginOverlay.classList.add('hidden');
        }

        showToast("Authenticated successfully!");

        // Reset inputs
        document.getElementById('login-username').value = '';
        document.getElementById('login-password').value = '';

        loadDashboardData();

        const urlParams = new URLSearchParams(window.location.search);
        const tabParam = urlParams.get('tab') || window.location.hash.substring(1);
        if (tabParam) {
            const tabButton = document.querySelector(`.menu-item[data-tab="${tabParam}"]`);
            if (tabButton) {
                tabButton.click();
            }
        }
    } catch (err) {
        errorEl.innerText = "Invalid username or password.";
        errorEl.style.display = 'block';
    }
}

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
    // Intercept submit on the login form
    const loginForm = document.getElementById('admin-login-form');
    if (loginForm) {
        loginForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const u = document.getElementById('login-username').value.trim();
            const p = document.getElementById('login-password').value;
            handleAdminLogin(u, p);
        });
    }

    // Add logout event listener
    const logoutBtn = document.getElementById('btn-logout');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', () => {
            handleUnauthorized();
            showToast("Logged out successfully.");
        });
    }

    // Add details modal close listeners
    const closeDetailsBtn = document.getElementById('btn-close-details-modal');
    if (closeDetailsBtn) {
        closeDetailsBtn.addEventListener('click', () => {
            document.getElementById('user-details-modal').classList.remove('show');
        });
    }
    const detailsModal = document.getElementById('user-details-modal');
    if (detailsModal) {
        detailsModal.addEventListener('click', (e) => {
            if (e.target === detailsModal) {
                detailsModal.classList.remove('show');
            }
        });
    }

    setupTabNavigation();
    setupEventHandlers();
    setupPromoCodeHandlers();
    setupLotteryHandlers();
    setupMinesHandlers();
    setupPlinkoHandlers();

    // Check initial authentication status
    const token = localStorage.getItem('adminToken');
    if (!token) {
        handleUnauthorized();
    } else {
        // Try verifying the token with stats endpoint
        originalFetch(`${API_BASE}/admin/stats`, {
            headers: { 'Authorization': `Bearer ${token}` }
        }).then(res => {
            if (res.ok) {
                const appContainer = document.querySelector('.app-container');
                if (appContainer) {
                    appContainer.style.display = 'flex';
                }
                const loginOverlay = document.getElementById('admin-login-overlay');
                if (loginOverlay) {
                    loginOverlay.classList.add('hidden');
                }

                loadDashboardData();

                // Handle URL parameter / Hash tab redirection
                const urlParams = new URLSearchParams(window.location.search);
                const tabParam = urlParams.get('tab') || window.location.hash.substring(1);
                if (tabParam) {
                    const tabButton = document.querySelector(`.menu-item[data-tab="${tabParam}"]`);
                    if (tabButton) {
                        tabButton.click();
                    }
                }

                // Automatically poll stats every 30 seconds if authenticated
                setInterval(() => {
                    if (localStorage.getItem('adminToken')) {
                        loadDashboardData();
                    }
                }, 30000);
            } else {
                handleUnauthorized();
            }
        }).catch(() => {
            handleUnauthorized();
        });
    }
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
        case 'mines-engine':
            el.pageTitle.innerText = "Mines Engine Controller";
            el.pageSubtitle.innerText = "Configure safety options, bet tiers, and monitor Mines games";
            break;
        case 'plinko-engine':
            el.pageTitle.innerText = "Plinko Engine Controller";
            el.pageSubtitle.innerText = "Manage Plinko drop mechanics, multipliers, and statistics";
            break;
        case 'fruit-manager':
            el.pageTitle.innerText = "Fruit Slicing Manager";
            el.pageSubtitle.innerText = "Manage Fruit Slicing tournaments, create new contests, and payout prizes";
            break;
        case 'puzzle-manager':
            el.pageTitle.innerText = "Slide Puzzle Manager";
            el.pageSubtitle.innerText = "Manage slide puzzle matches, configure image assets, and award winnings";
            break;
        case 'arrow-manager':
            el.pageTitle.innerText = "Go Arrows Manager";
            el.pageSubtitle.innerText = "Manage Go Arrows contest lobbies, configure board parameters, and award winnings";
            break;
        case 'word-manager':
            el.pageTitle.innerText = "Word Puzzle Manager";
            el.pageSubtitle.innerText = "Manage word puzzle contest lobbies, design vocabularies, and distribute rewards";
            break;
        case 'portfolio-manager':
            el.pageTitle.innerText = "Portfolio Website Manager";
            el.pageSubtitle.innerText = "Configure portfolio settings and manage user contact inquiries";
            break;
        case 'promo-codes':
            el.pageTitle.innerText = "Promo & Referral Codes Manager";
            el.pageSubtitle.innerText = "Create, edit, and delete default or custom promotional referral codes";
            break;
        case 'lottery-manager':
            el.pageTitle.innerText = "Lottery Engine Control Board";
            el.pageSubtitle.innerText = "Schedule lucky draws, monitor ticket sales, draw winners, and cancel contests";
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

    // Register listener for deposit method selector change
    const portDepositMethod = document.getElementById('port-deposit-method');
    if (portDepositMethod) {
        portDepositMethod.addEventListener('change', updateDepositFieldsVisibility);
    }

    // Portfolio Config Form Submit
    const portForm = document.getElementById('portfolio-config-form');
    if (portForm) {
        portForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const contact_email = document.getElementById('port-email').value.trim();
            const contact_phone = document.getElementById('port-phone').value.trim();
            const contact_address = document.getElementById('port-address').value.trim();
            const office_hours = document.getElementById('port-hours').value.trim();
            const apk_link = document.getElementById('port-apk').value.trim();
            const telegram_link = document.getElementById('port-telegram').value.trim();
            const instagram_link = document.getElementById('port-instagram').value.trim();
            const referral_code = document.getElementById('port-ref-code').value.trim().toUpperCase();

            const add_amount_method = document.getElementById('port-deposit-method').value;
            const admin_upi_id = document.getElementById('port-admin-upi').value.trim();
            const admin_bank_holder = document.getElementById('port-bank-holder').value.trim();
            const admin_bank_name = document.getElementById('port-bank-name').value.trim();
            const admin_bank_account = document.getElementById('port-bank-account').value.trim();
            const admin_bank_ifsc = document.getElementById('port-bank-ifsc').value.trim().toUpperCase();

            const payload = {
                contact_email,
                contact_phone,
                contact_address,
                office_hours,
                apk_link,
                telegram_link,
                instagram_link,
                referral_code,
                add_amount_method,
                admin_upi_id,
                admin_bank_holder,
                admin_bank_name,
                admin_bank_account,
                admin_bank_ifsc
            };

            const btn = portForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Saving...";

            try {
                const res = await fetch(`${API_BASE}/admin/portfolio/config`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error(await res.text());

                showToast("Portfolio settings saved successfully!");
                loadPortfolioManager();
            } catch (err) {
                showToast("Failed to save settings: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Save Settings";
            }
        });
    }

    // Admin Bank Accounts Modal Close / Open
    const btnAddAdminBank = document.getElementById('btn-add-admin-bank');
    const adminBankModal = document.getElementById('admin-bank-modal');
    const btnCloseBankModal = document.getElementById('btn-close-bank-modal');
    
    if (btnAddAdminBank && adminBankModal) {
        btnAddAdminBank.addEventListener('click', () => {
            document.getElementById('admin-bank-modal-title').innerText = "Add Bank Account";
            document.getElementById('modal-bank-id').value = "";
            document.getElementById('modal-bank-name').value = "";
            document.getElementById('modal-bank-holder').value = "";
            document.getElementById('modal-bank-account').value = "";
            document.getElementById('modal-bank-ifsc').value = "";
            document.getElementById('modal-bank-upi').value = "";
            document.getElementById('modal-bank-default').checked = false;
            document.getElementById('modal-bank-target-users').value = "";
            adminBankModal.classList.add('show');
        });
    }
    
    if (btnCloseBankModal && adminBankModal) {
        btnCloseBankModal.addEventListener('click', () => {
            adminBankModal.classList.remove('show');
        });
    }
    
    // Submit Admin Bank Details Form
    const modalAdminBankForm = document.getElementById('modal-admin-bank-form');
    if (modalAdminBankForm) {
        modalAdminBankForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const bankId = document.getElementById('modal-bank-id').value;
            const bankName = document.getElementById('modal-bank-name').value.trim();
            const holderName = document.getElementById('modal-bank-holder').value.trim();
            const accountNumber = document.getElementById('modal-bank-account').value.trim();
            const ifscCode = document.getElementById('modal-bank-ifsc').value.trim().toUpperCase();
            const upiId = document.getElementById('modal-bank-upi').value.trim();
            const isDefault = document.getElementById('modal-bank-default').checked;
            const targetUserIds = document.getElementById('modal-bank-target-users').value.trim();
            
            const payload = {
                bank_name: bankName,
                account_holder_name: holderName,
                account_number: accountNumber,
                ifsc_code: ifscCode,
                upi_id: upiId || null,
                is_default: isDefault,
                target_user_ids: targetUserIds || null
            };
            
            const url = bankId 
                ? `${API_BASE}/admin/portfolio/bank-details/${bankId}`
                : `${API_BASE}/admin/portfolio/bank-details`;
            const method = bankId ? 'PUT' : 'POST';
            
            try {
                const res = await fetch(url, {
                    method: method,
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                
                if (!res.ok) throw new Error(await res.text());
                
                showToast(bankId ? "Bank account updated successfully!" : "Bank account added successfully!");
                adminBankModal.classList.remove('show');
                loadAdminBankAccounts();
            } catch (err) {
                showToast("Failed to save bank account: " + err.message, true);
            }
        });
    }

    // Transactions History filtering event listeners
    const txSearch = document.getElementById('tx-search');
    const filterTxType = document.getElementById('filter-tx-type');
    const filterTxStatus = document.getElementById('filter-tx-status');
    if (txSearch) txSearch.addEventListener('input', filterTransactions);
    if (filterTxType) filterTxType.addEventListener('change', filterTransactions);
    if (filterTxStatus) filterTxStatus.addEventListener('change', filterTransactions);
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
        case 'mines-engine':
            loadMinesEngineData();
            break;
        case 'plinko-engine':
            loadPlinkoEngineData();
            break;
        case 'fruit-manager':
            loadFruitManager();
            break;
        case 'puzzle-manager':
            loadPuzzleManager();
            break;
        case 'arrow-manager':
            loadArrowManager();
            break;
        case 'word-manager':
            loadWordManager();
            break;
        case 'portfolio-manager':
            loadPortfolioManager();
            break;
        case 'promo-codes':
            loadPromoCodes();
            break;
        case 'lottery-manager':
            loadLotteryManager();
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

        const deleteBtn = u.is_banned
            ? `<button class="btn btn-action btn-ban" onclick="deleteUser(${u.id})">Delete User</button>`
            : '';

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
                        ${deleteBtn}
                        <button class="btn btn-action" style="background-color: rgba(0, 210, 255, 0.1); color: var(--primary); border: 1px solid rgba(0, 210, 255, 0.2);" onclick="openAdjustBalanceModal(${u.id}, '${u.name ? u.name.replace(/'/g, "\\'") : 'Anonymous'}', '${u.phone}')">Adjust Balance</button>
                        <button class="btn btn-action" style="background-color: rgba(255, 255, 255, 0.05); color: var(--text-main); border: 1px solid var(--border-color);" onclick="viewUserDetails(${u.id})">View Details</button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

async function viewUserDetails(userId) {
    let u = state.users ? state.users.find(x => x.id === userId) : null;
    if (!u) {
        try {
            const res = await fetch(`${API_BASE}/admin/users`);
            if (res.ok) {
                state.users = await res.json();
                u = state.users.find(x => x.id === userId);
            }
        } catch (e) {
            console.error("Failed to load users dynamically:", e);
        }
    }
    if (!u) {
        showToast("User details not found.", true);
        return;
    }

    const detailsContent = document.getElementById('user-details-content');
    detailsContent.innerHTML = `
        <!-- Profile & Status -->
        <div>
            <div class="profile-section-title">Personal Details</div>
            <div class="profile-info-grid">
                <div class="profile-card">
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">User ID</span>
                        <span class="profile-field-val">${u.id}</span>
                    </div>
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">Full Name</span>
                        <span class="profile-field-val">${u.name || (u.first_name ? `${u.first_name} ${u.last_name || ''}` : 'Anonymous')}</span>
                    </div>
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">Mobile Number</span>
                        <span class="profile-field-val">${u.phone}</span>
                    </div>
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">Email Address</span>
                        <span class="profile-field-val">${u.email || '-'}</span>
                    </div>
                </div>
                
                <div class="profile-card">
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">Referral Code</span>
                        <span class="profile-field-val">${u.referral_code}</span>
                    </div>
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">Referred By</span>
                        <span class="profile-field-val">${u.referred_by || '-'}</span>
                    </div>
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">KYC Status</span>
                        <span class="profile-field-val">
                            <span class="badge ${u.kyc_status === 'VERIFIED' ? 'badge-success' : 'badge-warning'}">
                                ${u.kyc_status}
                            </span>
                        </span>
                    </div>
                    <div class="profile-field-row">
                        <span class="profile-field-lbl">Account Status</span>
                        <span class="profile-field-val">
                            <span class="badge ${u.is_banned ? 'badge-error' : 'badge-success'}">
                                ${u.is_banned ? 'BANNED' : 'ACTIVE'}
                            </span>
                        </span>
                    </div>
                </div>
            </div>
        </div>

        <!-- Wallets & Finances -->
        <div>
            <div class="profile-section-title">Finances & Wallets</div>
            <div class="profile-stats-grid">
                <div class="profile-stat-box">
                    <div class="profile-stat-num dep">₹${u.deposit_balance.toFixed(2)}</div>
                    <div class="profile-stat-label">Deposit Wallet</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num win">₹${u.winning_balance.toFixed(2)}</div>
                    <div class="profile-stat-label">Winning Wallet</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num bon">₹${u.bonus_balance.toFixed(2)}</div>
                    <div class="profile-stat-label">Bonus Wallet</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num" style="color: var(--warning);">₹${(u.deposit_balance + u.winning_balance + u.bonus_balance).toFixed(2)}</div>
                    <div class="profile-stat-label">Total Value</div>
                </div>
            </div>
        </div>

        <!-- Bank Details -->
        <div>
            <div class="profile-section-title">Bank Details</div>
            <div class="profile-card" style="background: rgba(0, 210, 255, 0.02); border-color: rgba(0, 210, 255, 0.15);">
                ${u.bank_account_number ? `
                    <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px;">
                        <div>
                            <div class="profile-field-row">
                                <span class="profile-field-lbl">Holder Name</span>
                                <span class="profile-field-val" style="color: var(--primary);">${u.bank_account_holder_name}</span>
                            </div>
                            <div class="profile-field-row">
                                <span class="profile-field-lbl">Bank Name</span>
                                <span class="profile-field-val">${u.bank_name}</span>
                            </div>
                        </div>
                        <div>
                            <div class="profile-field-row">
                                <span class="profile-field-lbl">Account Number</span>
                                <span class="profile-field-val" style="font-family: monospace;">${u.bank_account_number}</span>
                            </div>
                            <div class="profile-field-row">
                                <span class="profile-field-lbl">IFSC Code</span>
                                <span class="profile-field-val" style="font-family: monospace; text-transform: uppercase;">${u.bank_ifsc_code}</span>
                            </div>
                        </div>
                    </div>
                ` : `
                    <div style="text-align: center; color: var(--text-muted); font-style: italic; padding: 10px 0;">
                        No bank accounts registered by this user.
                    </div>
                `}
            </div>
        </div>

        <!-- Game Metrics & Engagements -->
        <div>
            <div class="profile-section-title">Game Engagement Metrics</div>
            <div class="profile-stats-grid">
                <div class="profile-stat-box">
                    <div class="profile-stat-num" style="color: #fff;">${u.joined_contest_ids ? u.joined_contest_ids.length : 0} / ${u.completed_contest_ids ? u.completed_contest_ids.length : 0}</div>
                    <div class="profile-stat-label">Math Quiz (Join/End)</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num" style="color: #fff;">${u.joined_word_contest_ids ? u.joined_word_contest_ids.length : 0} / ${u.completed_word_contest_ids ? u.completed_word_contest_ids.length : 0}</div>
                    <div class="profile-stat-label">Word Guess (Join/End)</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num" style="color: #fff;">${u.joined_puzzle_contest_ids ? u.joined_puzzle_contest_ids.length : 0} / ${u.completed_puzzle_contest_ids ? u.completed_puzzle_contest_ids.length : 0}</div>
                    <div class="profile-stat-label">Slide Puzzle (Join/End)</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num" style="color: #fff;">${u.joined_fruit_contest_ids ? u.joined_fruit_contest_ids.length : 0} / ${u.completed_fruit_contest_ids ? u.completed_fruit_contest_ids.length : 0}</div>
                    <div class="profile-stat-label">Fruit Slicing (Join/End)</div>
                </div>
                <div class="profile-stat-box">
                    <div class="profile-stat-num" style="color: #fff;">${u.joined_arrow_contest_ids ? u.joined_arrow_contest_ids.length : 0} / ${u.completed_arrow_contest_ids ? u.completed_arrow_contest_ids.length : 0}</div>
                    <div class="profile-stat-label">Go Arrows (Join/End)</div>
                </div>
            </div>
        </div>

        <!-- Gameplay History Logs -->
        <div style="margin-top: 20px;">
            <div class="profile-section-title">Recent Gameplay History Logs</div>
            <div class="table-wrapper" style="max-height: 250px; overflow-y: auto;">
                <table class="data-table" style="font-size: 11px;">
                    <thead>
                        <tr>
                            <th>Game</th>
                            <th>Details</th>
                            <th>Bet</th>
                            <th>Multiplier</th>
                            <th>Payout</th>
                            <th>Status</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody id="user-game-logs-tbody">
                        <tr>
                            <td colspan="7" class="table-placeholder">Loading gameplay logs...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Wallet Transactions History Logs -->
        <div style="margin-top: 20px;">
            <div class="profile-section-title">Recent Wallet Transactions History Logs</div>
            <div class="table-wrapper" style="max-height: 250px; overflow-y: auto;">
                <table class="data-table" style="font-size: 11px;">
                    <thead>
                        <tr>
                            <th>Tx ID</th>
                            <th>Type</th>
                            <th>Amount</th>
                            <th>Status</th>
                            <th>Description</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody id="user-wallet-txs-tbody">
                        <tr>
                            <td colspan="6" class="table-placeholder">Loading transactions...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    `;

    document.getElementById('user-details-modal').classList.add('show');
    loadUserGameLogs(userId);
    loadUserWalletTransactions(userId);
}

window.viewUserDetails = viewUserDetails;


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

async function deleteUser(userId) {
    if (!confirm("Are you sure you want to permanently delete this banned user? This action cannot be undone and will delete all user metadata, transactions, history, and game records!")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/users/${userId}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());

        showToast("User deleted successfully!");
        loadUsers();
    } catch (err) {
        showToast("Error deleting user: " + err.message, true);
    }
}

window.deleteUser = deleteUser;


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

        const deleteBtn = `<button class="btn btn-action btn-ban" onclick="deleteContest(${c.id})">Delete</button>`;

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
                        ${deleteBtn}
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
        state.transactions = allTransactions;

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
                <td>
                    <span class="badge ${typeBadge}">${tx.type}</span>
                    ${tx.description ? `<div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">${tx.description}</div>` : ''}
                </td>
                <td><strong style="${typeStyle}">${prefix}₹${tx.amount.toFixed(2)}</strong></td>
                <td><span class="badge ${statusBadge}">${tx.status}</span></td>
                <td>${dateStr}</td>
            </tr>
        `;
    }).join('');
}

function filterTransactions() {
    const searchVal = document.getElementById('tx-search') ? document.getElementById('tx-search').value.toLowerCase().trim() : '';
    const typeVal = document.getElementById('filter-tx-type') ? document.getElementById('filter-tx-type').value : '';
    const statusVal = document.getElementById('filter-tx-status') ? document.getElementById('filter-tx-status').value : '';

    let filtered = state.transactions || [];

    if (searchVal) {
        filtered = filtered.filter(tx => {
            const userObj = state.users.find(u => u.id === tx.user_id);
            const phone = userObj ? userObj.phone : '';
            const name = userObj ? (userObj.name || '').toLowerCase() : '';
            const userIdStr = tx.user_id.toString();
            const txIdStr = tx.id.toString();
            const utrStr = (tx.utr || '').toLowerCase();
            return phone.includes(searchVal) || name.includes(searchVal) || userIdStr === searchVal || txIdStr === searchVal || utrStr.includes(searchVal);
        });
    }

    if (typeVal) {
        filtered = filtered.filter(tx => tx.type === typeVal);
    }

    if (statusVal) {
        filtered = filtered.filter(tx => tx.status === statusVal);
    }

    renderTransactionHistoryTable(filtered);
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

async function deleteContest(contestId) {
    if (!confirm("Are you sure you want to permanently delete this Trivia contest? This will delete all associated participants and attempts!")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/contests/${contestId}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Contest deleted successfully!");
        loadDashboardData();
    } catch (err) {
        showToast("Error deleting contest: " + err.message, true);
    }
}

window.deleteContest = deleteContest;


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
        // Fetch Quiz Maintenance status
        const maintenanceRes = await fetch(`${API_BASE}/admin/quiz/maintenance`);
        if (maintenanceRes.ok) {
            const m = await maintenanceRes.json();
            state.quiz_maintenance_active = m.maintenance_mode;
            const btn = document.getElementById('btn-toggle-quiz-maintenance');
            if (btn) {
                btn.innerText = state.quiz_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.quiz_maintenance_active ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

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

    // Quiz Maintenance Toggle Button
    const btnToggleQuizMaintenance = document.getElementById('btn-toggle-quiz-maintenance');
    if (btnToggleQuizMaintenance) {
        btnToggleQuizMaintenance.addEventListener('click', async () => {
            const nextMode = !state.quiz_maintenance_active;
            btnToggleQuizMaintenance.disabled = true;

            try {
                const res = await fetch(`${API_BASE}/admin/quiz/maintenance?enabled=${nextMode}`, {
                    method: 'POST'
                });
                if (!res.ok) throw new Error("Failed to change maintenance status.");

                state.quiz_maintenance_active = nextMode;
                btnToggleQuizMaintenance.innerText = state.quiz_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btnToggleQuizMaintenance.style.backgroundColor = state.quiz_maintenance_active ? 'var(--success)' : 'var(--error)';
                showToast(state.quiz_maintenance_active ? "Quiz Game has been LOCKED for maintenance." : "Quiz Game unlocked! Game access is live.");
            } catch (err) {
                showToast("Maintenance toggle error: " + err.message, true);
            } finally {
                btnToggleQuizMaintenance.disabled = false;
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
            const prevSelectedVal = parseInt(tierSelect.value);

            // Build option list dynamically
            tierSelect.innerHTML = state.rtp_settings.map(r => {
                const label = r.min_amount === r.max_amount
                    ? `Exact Bet ₹${r.min_amount}`
                    : `Bets ₹${r.min_amount} – ₹${r.max_amount}`;
                return `<option value="${r.id}">${label}</option>`;
            }).join('');

            // Preserve selection if it still exists
            if (prevSelectedVal && state.rtp_settings.some(r => r.id === prevSelectedVal)) {
                tierSelect.value = prevSelectedVal;
            }

            const tierVal = parseInt(tierSelect.value);
            const setting = state.rtp_settings.find(r => r.id === tierVal);
            if (setting) {
                // Pretty print JSON
                try {
                    const parsed = JSON.parse(setting.probability_json);
                    document.getElementById('rtp-json-editor').value = JSON.stringify(parsed, null, 4);
                } catch (_) {
                    document.getElementById('rtp-json-editor').value = setting.probability_json;
                }
            } else {
                document.getElementById('rtp-json-editor').value = '';
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
                    <td><strong style="cursor: pointer; color: var(--primary);" onclick="viewUserDetails(${s.user_id})">${s.user_name || s.user_phone}</strong></td>
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
            } else {
                document.getElementById('rtp-json-editor').value = '';
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

    // 2.1 RTP Delete Tier button
    const btnDeleteRtp = document.getElementById('btn-delete-rtp-tier');
    if (btnDeleteRtp) {
        btnDeleteRtp.addEventListener('click', async () => {
            const tierId = parseInt(document.getElementById('rtp-tier-select').value);
            if (isNaN(tierId)) {
                showToast("Please select a tier to delete.", true);
                return;
            }
            if (!confirm("Are you sure you want to delete this RTP setting override/tier?")) return;

            btnDeleteRtp.disabled = true;
            try {
                const response = await fetch(`${API_BASE}/admin/rtp/${tierId}`, {
                    method: 'DELETE'
                });
                if (!response.ok) {
                    const errText = await response.text();
                    throw new Error(errText || "Failed to delete tier.");
                }
                showToast("RTP tier deleted successfully!");
                document.getElementById('rtp-tier-select').value = "";
                await loadSpinEngineData();
            } catch (err) {
                console.error(err);
                showToast("Error deleting RTP tier: " + err.message, true);
            } finally {
                btnDeleteRtp.disabled = false;
            }
        });
    }

    // 2.2 RTP Create Tier Form submission
    const createRtpForm = document.getElementById('spin-rtp-create-form');
    if (createRtpForm) {
        createRtpForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const minBet = parseFloat(document.getElementById('rtp-create-min').value);
            const maxBet = parseFloat(document.getElementById('rtp-create-max').value);
            const rawJson = document.getElementById('rtp-create-json').value.trim();

            if (isNaN(minBet) || isNaN(maxBet) || !rawJson) {
                showToast("Please fill all creation fields.", true);
                return;
            }

            const btn = createRtpForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Creating...";

            try {
                const parsed = JSON.parse(rawJson);
                const sum = Object.values(parsed).reduce((a, b) => a + b, 0);
                if (Math.abs(sum - 100) > 1.0) {
                    throw new Error(`Total probability weights must sum to exactly 100%. (Current sum: ${sum}%)`);
                }

                const response = await fetch(`${API_BASE}/admin/rtp`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        min_amount: minBet,
                        max_amount: maxBet,
                        probability_json: JSON.stringify(parsed),
                        enabled: true
                    })
                });

                if (!response.ok) {
                    const errText = await response.text();
                    throw new Error(errText || "Failed to create RTP setting.");
                }

                showToast("RTP setting tier/override created successfully!");
                document.getElementById('rtp-create-json').value = '';
                await loadSpinEngineData();
            } catch (err) {
                console.error(err);
                showToast("Creation error: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Create Override / Tier";
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
        // Fetch Fruit Maintenance status
        const maintenanceRes = await fetch(`${API_BASE}/admin/fruit-slicing/maintenance`);
        if (maintenanceRes.ok) {
            const m = await maintenanceRes.json();
            state.fruit_maintenance_active = m.maintenance_mode;
            const btn = document.getElementById('btn-toggle-fruit-maintenance');
            if (btn) {
                btn.innerText = state.fruit_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.fruit_maintenance_active ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

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

                const deleteBtn = `<button class="btn btn-action btn-ban" onclick="deleteFruitContest(${c.id})">Delete</button>`;

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
                                ${deleteBtn}
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

async function deleteFruitContest(contestId) {
    if (!confirm("Are you sure you want to permanently delete this Fruit Slicing contest? This will delete all associated matches and results!")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/fruit-slicing/contests/${contestId}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Fruit contest deleted successfully!");
        loadFruitManager();
    } catch (err) {
        showToast("Error deleting Fruit contest: " + err.message, true);
    }
}

window.deleteFruitContest = deleteFruitContest;
window.completeFruitContest = completeFruitContest;


// ==========================================
// IMAGE SLIDE PUZZLE MANAGER CONTROLLER
// ==========================================

async function loadPuzzleManager() {
    try {
        // Fetch Puzzle Maintenance status
        const maintenanceRes = await fetch(`${API_BASE}/admin/puzzle/maintenance`);
        if (maintenanceRes.ok) {
            const m = await maintenanceRes.json();
            state.puzzle_maintenance_active = m.maintenance_mode;
            const btn = document.getElementById('btn-toggle-puzzle-maintenance');
            if (btn) {
                btn.innerText = state.puzzle_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.puzzle_maintenance_active ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

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

                const deleteBtn = `<button class="btn btn-action btn-ban" onclick="deletePuzzleContest(${c.id})">Delete</button>`;

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
                                ${deleteBtn}
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

async function deletePuzzleContest(contestId) {
    if (!confirm("Are you sure you want to permanently delete this Puzzle contest? This will delete all associated attempts and games!")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/puzzle/contests/${contestId}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Puzzle contest deleted successfully!");
        loadPuzzleManager();
    } catch (err) {
        showToast("Error deleting Puzzle contest: " + err.message, true);
    }
}

window.deletePuzzleContest = deletePuzzleContest;
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
        // Fetch Word Maintenance status
        const maintenanceRes = await fetch(`${API_BASE}/admin/word-puzzle/maintenance`);
        if (maintenanceRes.ok) {
            const m = await maintenanceRes.json();
            state.word_maintenance_active = m.maintenance_mode;
            const btn = document.getElementById('btn-toggle-word-maintenance');
            if (btn) {
                btn.innerText = state.word_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.word_maintenance_active ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

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

                const deleteBtn = `<button class="btn btn-action btn-ban" onclick="deleteWordContest(${c.id})">Delete</button>`;

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
                                ${deleteBtn}
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

async function deleteWordContest(contestId) {
    if (!confirm("Are you sure you want to permanently delete this Word contest? This will delete all questions, attempts, and answers!")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/word-puzzle/contests/${contestId}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Word contest deleted successfully!");
        loadWordManager();
    } catch (err) {
        showToast("Error deleting Word contest: " + err.message, true);
    }
}

window.deleteWordContest = deleteWordContest;
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

document.addEventListener('DOMContentLoaded', () => {
    // Fruit Maintenance Toggle Button
    const btnToggleFruitMaintenance = document.getElementById('btn-toggle-fruit-maintenance');
    if (btnToggleFruitMaintenance) {
        btnToggleFruitMaintenance.addEventListener('click', async () => {
            const nextMode = !state.fruit_maintenance_active;
            btnToggleFruitMaintenance.disabled = true;

            try {
                const res = await fetch(`${API_BASE}/admin/fruit-slicing/maintenance?enabled=${nextMode}`, {
                    method: 'POST'
                });
                if (!res.ok) throw new Error("Failed to change maintenance status.");

                state.fruit_maintenance_active = nextMode;
                btnToggleFruitMaintenance.innerText = state.fruit_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btnToggleFruitMaintenance.style.backgroundColor = state.fruit_maintenance_active ? 'var(--success)' : 'var(--error)';
                showToast(state.fruit_maintenance_active ? "Fruit Game has been LOCKED for maintenance." : "Fruit Game unlocked! Game access is live.");
            } catch (err) {
                showToast("Maintenance toggle error: " + err.message, true);
            } finally {
                btnToggleFruitMaintenance.disabled = false;
            }
        });
    }

    // Puzzle Maintenance Toggle Button
    const btnTogglePuzzleMaintenance = document.getElementById('btn-toggle-puzzle-maintenance');
    if (btnTogglePuzzleMaintenance) {
        btnTogglePuzzleMaintenance.addEventListener('click', async () => {
            const nextMode = !state.puzzle_maintenance_active;
            btnTogglePuzzleMaintenance.disabled = true;

            try {
                const res = await fetch(`${API_BASE}/admin/puzzle/maintenance?enabled=${nextMode}`, {
                    method: 'POST'
                });
                if (!res.ok) throw new Error("Failed to change maintenance status.");

                state.puzzle_maintenance_active = nextMode;
                btnTogglePuzzleMaintenance.innerText = state.puzzle_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btnTogglePuzzleMaintenance.style.backgroundColor = state.puzzle_maintenance_active ? 'var(--success)' : 'var(--error)';
                showToast(state.puzzle_maintenance_active ? "Image Puzzle has been LOCKED for maintenance." : "Image Puzzle unlocked! Game access is live.");
            } catch (err) {
                showToast("Maintenance toggle error: " + err.message, true);
            } finally {
                btnTogglePuzzleMaintenance.disabled = false;
            }
        });
    }

    // Word Maintenance Toggle Button
    const btnToggleWordMaintenance = document.getElementById('btn-toggle-word-maintenance');
    if (btnToggleWordMaintenance) {
        btnToggleWordMaintenance.addEventListener('click', async () => {
            const nextMode = !state.word_maintenance_active;
            btnToggleWordMaintenance.disabled = true;

            try {
                const res = await fetch(`${API_BASE}/admin/word-puzzle/maintenance?enabled=${nextMode}`, {
                    method: 'POST'
                });
                if (!res.ok) throw new Error("Failed to change maintenance status.");

                state.word_maintenance_active = nextMode;
                btnToggleWordMaintenance.innerText = state.word_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btnToggleWordMaintenance.style.backgroundColor = state.word_maintenance_active ? 'var(--success)' : 'var(--error)';
                showToast(state.word_maintenance_active ? "Word Game has been LOCKED for maintenance." : "Word Game unlocked! Game access is live.");
            } catch (err) {
                showToast("Maintenance toggle error: " + err.message, true);
            } finally {
                btnToggleWordMaintenance.disabled = false;
            }
        });
    }

    // Arrow Maintenance Toggle Button
    const btnToggleArrowMaintenance = document.getElementById('btn-toggle-arrow-maintenance');
    if (btnToggleArrowMaintenance) {
        btnToggleArrowMaintenance.addEventListener('click', async () => {
            const nextMode = !state.arrow_maintenance_active;
            btnToggleArrowMaintenance.disabled = true;

            try {
                const res = await fetch(`${API_BASE}/admin/arrow/maintenance/toggle`, {
                    method: 'POST'
                });
                if (!res.ok) throw new Error("Failed to change maintenance status.");

                state.arrow_maintenance_active = nextMode;
                btnToggleArrowMaintenance.innerText = state.arrow_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btnToggleArrowMaintenance.style.backgroundColor = state.arrow_maintenance_active ? 'var(--success)' : 'var(--error)';
                showToast(state.arrow_maintenance_active ? "Go Arrows has been LOCKED for maintenance." : "Go Arrows unlocked! Game access is live.");
            } catch (err) {
                showToast("Maintenance toggle error: " + err.message, true);
            } finally {
                btnToggleArrowMaintenance.disabled = false;
            }
        });
    }

    // Arrow Difficulty Auto Preset
    const acDiff = document.getElementById('ac-difficulty');
    if (acDiff) {
        acDiff.addEventListener('change', () => {
            const diff = acDiff.value;
            const sizeSelect = document.getElementById('ac-grid-size');
            const countInput = document.getElementById('ac-arrow-count');
            const durInput = document.getElementById('ac-duration');

            if (diff === 'EASY') {
                if (sizeSelect) sizeSelect.value = '8';
                if (countInput) countInput.value = '50';
                if (durInput) durInput.value = '60';
            } else if (diff === 'MEDIUM') {
                if (sizeSelect) sizeSelect.value = '10';
                if (countInput) countInput.value = '80';
                if (durInput) durInput.value = '90';
            } else if (diff === 'HARD') {
                if (sizeSelect) sizeSelect.value = '12';
                if (countInput) countInput.value = '150';
                if (durInput) durInput.value = '120';
            } else if (diff === 'EXPERT') {
                if (sizeSelect) sizeSelect.value = '15';
                if (countInput) countInput.value = '250';
                if (durInput) durInput.value = '180';
            }
            // Trigger custom visibility check
            if (sizeSelect) sizeSelect.dispatchEvent(new Event('change'));
        });
    }

    // Arrow Grid Size Custom toggle
    const acGridSelect = document.getElementById('ac-grid-size');
    if (acGridSelect) {
        acGridSelect.addEventListener('change', () => {
            const customRow = document.getElementById('ac-custom-grid-row');
            if (customRow) {
                customRow.style.display = acGridSelect.value === 'custom' ? 'flex' : 'none';
            }
        });
    }

    // 2. Add rule button for Arrows
    const btnAcAddRule = document.getElementById('btn-ac-add-prize-rule');
    if (btnAcAddRule) {
        btnAcAddRule.addEventListener('click', () => {
            addPrizeRuleRow('ac-prize-rules-list');
        });
    }

    // 3. Launch Arrow Contest form submit
    const acForm = document.getElementById('arrow-contest-form');
    if (acForm) {
        acForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const btn = acForm.querySelector('button[type="submit"]');
            btn.innerText = "Launching...";
            btn.disabled = true;

            const rules = [];
            acForm.querySelectorAll('.prize-rule-row').forEach(row => {
                const minRank = parseInt(row.querySelector('.rule-min-rank').value);
                const maxRank = parseInt(row.querySelector('.rule-max-rank').value);
                const prize = parseFloat(row.querySelector('.rule-prize').value);
                if (minRank && maxRank && !isNaN(prize)) {
                    rules.push({ min_rank: minRank, max_rank: maxRank, prize: prize });
                }
            });

            let gridSize = 10;
            const sizeVal = document.getElementById('ac-grid-size').value;
            if (sizeVal === 'custom') {
                gridSize = parseInt(document.getElementById('ac-grid-size-custom').value) || 10;
            } else {
                gridSize = parseInt(sizeVal);
            }

            const payload = {
                title: document.getElementById('ac-title').value.trim(),
                entry_fee: parseFloat(document.getElementById('ac-fee').value),
                total_slots: parseInt(document.getElementById('ac-slots').value),
                prize_pool: parseFloat(document.getElementById('ac-pool').value),
                grid_size: gridSize,
                duration_seconds: parseInt(document.getElementById('ac-duration').value),
                difficulty: document.getElementById('ac-difficulty').value,
                arrow_count: parseInt(document.getElementById('ac-arrow-count').value),
                start_time: new Date(document.getElementById('ac-start-time').value).toISOString(),
                prize_rules: rules
            };

            const endTimeVal = document.getElementById('ac-end-time').value;
            if (endTimeVal) {
                payload.end_time = new Date(endTimeVal).toISOString();
            }

            try {
                const res = await fetch(`${API_BASE}/admin/arrow/contests`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) {
                    const err = await res.json();
                    throw new Error(err.detail || "Failed to launch contest.");
                }
                showToast("Go Arrows tournament launched successfully!");
                acForm.reset();
                document.getElementById('ac-prize-rules-list').innerHTML = '';
                const customRow = document.getElementById('ac-custom-grid-row');
                if (customRow) customRow.style.display = 'none';
                loadArrowManager();
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btn.innerText = "Launch Arrow Contest";
                btn.disabled = false;
            }
        });
    }
});


// ==========================================
// GO ARROWS GAME ENGINE ADMINISTRATIVE CONTROLLERS
// ==========================================

async function loadArrowManager() {
    try {
        // Fetch Arrow Maintenance status
        const maintenanceRes = await fetch(`${API_BASE}/admin/arrow/maintenance`);
        if (maintenanceRes.ok) {
            const m = await maintenanceRes.json();
            state.arrow_maintenance_active = m.maintenance_mode;
            const btn = document.getElementById('btn-toggle-arrow-maintenance');
            if (btn) {
                btn.innerText = state.arrow_maintenance_active ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.arrow_maintenance_active ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

        const res = await fetch(`${API_BASE}/arrow/contests`);
        if (!res.ok) throw new Error("Failed to load Go Arrows contests.");
        const contests = await res.json();

        // 1. Calculate stats
        const activeCount = contests.filter(c => c.status === 'ACTIVE').length;
        document.getElementById('arrow-stat-active').innerText = activeCount;

        // 2. Render table
        const tbody = document.getElementById('arrow-contests-table-body');
        if (tbody) {
            if (contests.length === 0) {
                tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder">No Go Arrows contests active or defined yet.</td></tr>`;
                return;
            }

            tbody.innerHTML = contests.map(c => {
                let statusBadge = 'badge-warning';
                if (c.status === 'ACTIVE') statusBadge = 'badge-success';
                if (c.status === 'COMPLETED') statusBadge = 'badge-info';

                const startTimeStr = new Date(c.start_time).toLocaleString();
                const endTimeStr = c.end_time ? new Date(c.end_time).toLocaleString() : 'N/A';

                const actionBtn = c.status !== 'COMPLETED'
                    ? `<button class="btn btn-action btn-unban" onclick="completeArrowContest(${c.id})">Complete</button>`
                    : `<span class="text-muted" style="font-size:12px;">Payout Done</span>`;

                const deleteBtn = `<button class="btn btn-action btn-ban" onclick="deleteArrowContest(${c.id})">Delete</button>`;

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
                                <div><strong>Board Size:</strong> ${c.grid_size}x${c.grid_size}</div>
                                <div><strong>Difficulty:</strong> <span class="badge badge-info" style="font-size: 9px; padding: 1px 4px; border-radius: 4px;">${c.difficulty || 'MEDIUM'}</span></div>
                                <div><strong>Arrows:</strong> ${c.arrow_count || 'N/A'}</div>
                                <div><strong>Solve Limit:</strong> ${c.duration_seconds}s</div>
                                <div><strong>Start:</strong> ${startTimeStr}</div>
                                <div><strong>End:</strong> ${endTimeStr}</div>
                            </div>
                        </td>
                        <td><span class="badge ${statusBadge}">${c.status}</span></td>
                        <td>
                            <div style="display:flex; gap:8px;">
                                ${actionBtn}
                                ${deleteBtn}
                            </div>
                        </td>
                    </tr>
                `;
            }).join('');
        }
    } catch (err) {
        showToast(err.message, true);
        const tbody = document.getElementById('arrow-contests-table-body');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="8" class="table-placeholder" style="color: var(--error);">Failed to load Go Arrows contests: ${err.message}</td></tr>`;
        }
    }
}

async function completeArrowContest(contestId) {
    if (!confirm("Are you sure you want to complete this Go Arrows contest and award the winners?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/arrow/contests/${contestId}/complete`, {
            method: 'POST'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Go Arrows contest completed and prize payouts distributed!");
        loadArrowManager();
    } catch (err) {
        showToast("Error completing Go Arrows contest: " + err.message, true);
    }
}

async function deleteArrowContest(contestId) {
    if (!confirm("Are you sure you want to permanently delete this Go Arrows contest? This will delete all associated attempts and games!")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/arrow/contests/${contestId}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Go Arrows contest deleted successfully!");
        loadArrowManager();
    } catch (err) {
        showToast("Error deleting Go Arrows contest: " + err.message, true);
    }
}

window.deleteArrowContest = deleteArrowContest;
window.completeArrowContest = completeArrowContest;

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function updateDepositFieldsVisibility() {
    const portDepositMethod = document.getElementById('port-deposit-method');
    const portUpiGroup = document.getElementById('port-upi-group');
    const portBankGroup = document.getElementById('port-bank-group');
    if (!portDepositMethod) return;
    const val = portDepositMethod.value;
    if (val === 'UPI') {
        if (portUpiGroup) portUpiGroup.style.display = 'block';
        if (portBankGroup) portBankGroup.style.display = 'none';
    } else if (val === 'BANK') {
        if (portUpiGroup) portUpiGroup.style.display = 'none';
        if (portBankGroup) portBankGroup.style.display = 'block';
    } else {
        if (portUpiGroup) portUpiGroup.style.display = 'none';
        if (portBankGroup) portBankGroup.style.display = 'none';
    }
}

async function loadPortfolioManager() {
    try {
        const configRes = await fetch(`${API_BASE}/portfolio/config`);
        if (configRes.ok) {
            const config = await configRes.json();
            document.getElementById('port-email').value = config.contact_email || '';
            document.getElementById('port-phone').value = config.contact_phone || '';
            document.getElementById('port-address').value = config.contact_address || '';
            document.getElementById('port-hours').value = config.office_hours || '';
            document.getElementById('port-apk').value = config.apk_link || '';
            document.getElementById('port-telegram').value = config.telegram_link || '';
            document.getElementById('port-instagram').value = config.instagram_link || '';
            document.getElementById('port-ref-code').value = config.referral_code || '';

            document.getElementById('port-deposit-method').value = config.add_amount_method || 'UPI';
            document.getElementById('port-admin-upi').value = config.admin_upi_id || '';
            document.getElementById('port-bank-holder').value = config.admin_bank_holder || '';
            document.getElementById('port-bank-name').value = config.admin_bank_name || '';
            document.getElementById('port-bank-account').value = config.admin_bank_account || '';
            document.getElementById('port-bank-ifsc').value = config.admin_bank_ifsc || '';

            updateDepositFieldsVisibility();
        }
        await loadPortfolioInquiries();
        await loadAdminBankAccounts();
    } catch (err) {
        showToast("Error loading portfolio: " + err.message, true);
    }
}

let adminBankAccountsList = [];

async function loadAdminBankAccounts() {
    try {
        const res = await fetch(`${API_BASE}/admin/portfolio/bank-details`);
        if (!res.ok) throw new Error("Failed to load bank details.");
        adminBankAccountsList = await res.json();
        renderAdminBankTable(adminBankAccountsList);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderAdminBankTable(details) {
    const tbody = document.getElementById('admin-bank-table-body');
    if (!tbody) return;
    if (details.length === 0) {
        tbody.innerHTML = `<tr><td colspan="9" class="table-placeholder">No bank accounts added yet. Click "+ Add Bank Account" above.</td></tr>`;
        return;
    }
    tbody.innerHTML = details.map(d => {
        return `
            <tr>
                <td>${d.id}</td>
                <td><strong>${escapeHtml(d.bank_name)}</strong></td>
                <td>${escapeHtml(d.account_holder_name)}</td>
                <td><code>${escapeHtml(d.account_number)}</code></td>
                <td><code>${escapeHtml(d.ifsc_code)}</code></td>
                <td>${d.upi_id ? `<code>${escapeHtml(d.upi_id)}</code>` : '<span class="text-muted">-</span>'}</td>
                <td>${d.is_default ? '<span class="badge badge-success">DEFAULT</span>' : '<span class="text-muted">No</span>'}</td>
                <td>${d.target_user_ids ? `<span class="badge badge-info">${escapeHtml(d.target_user_ids)}</span>` : '<span class="text-muted">All Users</span>'}</td>
                <td>
                    <div style="display: flex; gap: 8px;">
                        <button class="btn btn-action" onclick="openEditBankModal(${d.id})">Edit</button>
                        <button class="btn btn-action btn-ban" onclick="deleteBankDetail(${d.id})">Delete</button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

window.openEditBankModal = function(id) {
    const d = adminBankAccountsList.find(x => x.id === id);
    if (!d) return;
    document.getElementById('admin-bank-modal-title').innerText = "Edit Bank Account";
    document.getElementById('modal-bank-id').value = d.id;
    document.getElementById('modal-bank-name').value = d.bank_name || '';
    document.getElementById('modal-bank-holder').value = d.account_holder_name || '';
    document.getElementById('modal-bank-account').value = d.account_number || '';
    document.getElementById('modal-bank-ifsc').value = d.ifsc_code || '';
    document.getElementById('modal-bank-upi').value = d.upi_id || '';
    document.getElementById('modal-bank-default').checked = d.is_default || false;
    document.getElementById('modal-bank-target-users').value = d.target_user_ids || '';
    document.getElementById('admin-bank-modal').classList.add('show');
}

window.deleteBankDetail = async function(id) {
    if (!confirm("Are you sure you want to delete this bank account?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/portfolio/bank-details/${id}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Bank account deleted successfully!");
        loadAdminBankAccounts();
    } catch (err) {
        showToast("Failed to delete bank account: " + err.message, true);
    }
}

async function loadPortfolioInquiries() {
    try {
        const queriesRes = await fetch(`${API_BASE}/admin/portfolio/contacts`);
        if (!queriesRes.ok) throw new Error("Failed to load inquiries.");
        const queries = await queriesRes.json();
        renderPortfolioQueries(queries);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderPortfolioQueries(queries) {
    const tbody = document.getElementById('portfolio-queries-table-body');
    if (!tbody) return;
    if (queries.length === 0) {
        tbody.innerHTML = `<tr><td colspan="7" class="table-placeholder">No inquiries received yet.</td></tr>`;
        return;
    }
    tbody.innerHTML = queries.map(q => {
        const dateStr = new Date(q.created_at).toLocaleString();
        return `
            <tr>
                <td>${q.id}</td>
                <td>${dateStr}</td>
                <td><strong>${escapeHtml(q.name)}</strong></td>
                <td><a href="mailto:${escapeHtml(q.email)}" style="color: var(--primary); text-decoration: underline;">${escapeHtml(q.email)}</a></td>
                <td>${escapeHtml(q.subject)}</td>
                <td><div style="max-width: 250px; overflow-wrap: break-word; font-size: 12px; color: var(--text-muted);">${escapeHtml(q.message)}</div></td>
                <td>
                    <button class="btn btn-action btn-ban" onclick="deleteQuery(${q.id})" style="background: rgba(255, 23, 68, 0.1); color: var(--error); border-color: rgba(255, 23, 68, 0.2);">Delete</button>
                </td>
            </tr>
        `;
    }).join('');
}

async function deleteQuery(id) {
    if (!confirm("Are you sure you want to delete this inquiry?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/portfolio/contacts/${id}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Inquiry deleted successfully.");
        loadPortfolioInquiries();
    } catch (err) {
        showToast("Failed to delete inquiry: " + err.message, true);
    }
}

window.deleteQuery = deleteQuery;
window.loadPortfolioManager = loadPortfolioManager;


// ==========================================
// PROMO CODES MANAGEMENT
// ==========================================
state.promoCodes = [];

async function loadPromoCodes() {
    try {
        const res = await fetch(`${API_BASE}/admin/promo-codes`);
        if (!res.ok) throw new Error("Failed to load promo codes list.");
        state.promoCodes = await res.json();
        renderPromoCodesTable(state.promoCodes);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderPromoCodesTable(promoList) {
    const tbody = document.getElementById('promo-codes-table-body');
    if (!tbody) return;
    if (promoList.length === 0) {
        tbody.innerHTML = `<tr><td colspan="4" class="table-placeholder">No promo codes found.</td></tr>`;
        return;
    }

    tbody.innerHTML = promoList.map(p => {
        return `
            <tr>
                <td><strong>${escapeHtml(p.code)}</strong></td>
                <td>₹${p.bonus_amount.toFixed(2)}</td>
                <td>${escapeHtml(p.description || '')}</td>
                <td>
                    <div style="display: flex; gap: 8px; align-items: center;">
                        <button class="btn btn-action" onclick="editPromoCode(${p.id})">Edit</button>
                        <button class="btn btn-action btn-ban" onclick="deletePromoCode(${p.id})" style="background: rgba(255, 23, 68, 0.1); color: var(--error); border-color: rgba(255, 23, 68, 0.2);">Delete</button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

function editPromoCode(id) {
    const promo = state.promoCodes.find(p => p.id === id);
    if (!promo) return;

    document.getElementById('promo-id').value = promo.id;
    document.getElementById('promo-code').value = promo.code;
    document.getElementById('promo-bonus').value = promo.bonus_amount;
    document.getElementById('promo-description').value = promo.description || '';

    document.getElementById('promo-form-title').innerText = "Edit Promo Referral Code";
    document.getElementById('btn-promo-submit').innerText = "Save Changes";
    document.getElementById('btn-promo-cancel').style.display = "block";
}

async function deletePromoCode(id) {
    if (!confirm("Are you sure you want to delete this promo code?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/promo-codes/${id}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());
        showToast("Promo code deleted successfully.");
        loadPromoCodes();
    } catch (err) {
        showToast("Failed to delete promo code: " + err.message, true);
    }
}

function setupPromoCodeHandlers() {
    const promoForm = document.getElementById('promo-code-form');
    if (promoForm) {
        promoForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const id = document.getElementById('promo-id').value;
            const code = document.getElementById('promo-code').value.trim().toUpperCase();
            const bonus_amount = parseFloat(document.getElementById('promo-bonus').value);
            const description = document.getElementById('promo-description').value.trim();

            const payload = {
                code,
                bonus_amount,
                description
            };

            const isEdit = id && id.length > 0;
            const url = isEdit ? `${API_BASE}/admin/promo-codes/${id}` : `${API_BASE}/admin/promo-codes`;
            const method = isEdit ? 'PUT' : 'POST';

            const btn = document.getElementById('btn-promo-submit');
            btn.disabled = true;
            btn.innerText = "Saving...";

            try {
                const res = await fetch(url, {
                    method: method,
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                if (!res.ok) throw new Error(await res.text());

                showToast(isEdit ? "Promo code updated successfully!" : "Promo code created successfully!");
                resetPromoForm();
                loadPromoCodes();
            } catch (err) {
                showToast("Failed to save promo code: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = isEdit ? "Save Changes" : "Create Code";
            }
        });
    }

    const btnCancel = document.getElementById('btn-promo-cancel');
    if (btnCancel) {
        btnCancel.addEventListener('click', () => {
            resetPromoForm();
        });
    }
}

function resetPromoForm() {
    document.getElementById('promo-id').value = '';
    document.getElementById('promo-code').value = '';
    document.getElementById('promo-bonus').value = '25';
    document.getElementById('promo-description').value = '';

    document.getElementById('promo-form-title').innerText = "Create Promo Referral Code";
    document.getElementById('btn-promo-submit').innerText = "Create Code";
    document.getElementById('btn-promo-cancel').style.display = "none";
}

window.editPromoCode = editPromoCode;
window.deletePromoCode = deletePromoCode;
window.loadPromoCodes = loadPromoCodes;
window.setupPromoCodeHandlers = setupPromoCodeHandlers;


function setupLotteryHandlers() {
    const form = document.getElementById('lottery-create-form');
    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const title = document.getElementById('l-title').value.trim();
            const price = parseFloat(document.getElementById('l-price').value);
            const pool = parseFloat(document.getElementById('l-pool').value);
            const maxTickets = parseInt(document.getElementById('l-max-tickets').value);
            const drawTimeStr = document.getElementById('l-draw-time').value;
            const winPercent = parseFloat(document.getElementById('l-win-percent').value);
            const forcedNumberVal = document.getElementById('l-forced-number').value.trim();
            const forcedNumber = forcedNumberVal || null;

            if (!title || isNaN(price) || isNaN(pool) || isNaN(maxTickets) || !drawTimeStr || isNaN(winPercent)) {
                showToast("Please fill in all fields correctly.", true);
                return;
            }

            const drawTime = new Date(drawTimeStr).toISOString();

            try {
                const response = await fetch(`${API_BASE}/admin/lottery/draws`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        title: title,
                        ticket_price: price,
                        prize_pool: pool,
                        draw_time: drawTime,
                        max_tickets: maxTickets,
                        win_percentage: winPercent,
                        forced_winning_number: forcedNumber
                    })
                });

                if (!response.ok) throw new Error(await response.text());

                showToast("Lottery Draw launched successfully!");
                form.reset();
                loadLotteryManager();
            } catch (err) {
                console.error(err);
                showToast("Failed to create lottery: " + err.message, true);
            }
        });
    }
}

async function loadLotteryManager() {
    try {
        const res = await fetch(`${API_BASE}/admin/lottery/draws`);
        if (!res.ok) throw new Error("Failed to load lottery draws schedule.");
        const draws = await res.json();
        renderLotteryTable(draws);
    } catch (err) {
        showToast(err.message, true);
    }
}

function renderLotteryTable(draws) {
    const tableBody = document.getElementById('lottery-draws-table-body');
    if (!tableBody) return;

    if (draws.length === 0) {
        tableBody.innerHTML = `<tr><td colspan="11" class="table-placeholder">No lottery draws scheduled yet.</td></tr>`;
        return;
    }

    tableBody.innerHTML = draws.map(draw => {
        const isCompleted = draw.status === 'COMPLETED';
        const isCancelled = draw.status === 'CANCELLED';
        const isOpen = draw.status === 'OPEN';

        let statusBadge = `<span class="badge badge-success">Open</span>`;
        if (isCompleted) {
            statusBadge = `<span class="badge badge-neutral" style="background-color: var(--text-muted); color: #fff;">Drawn</span>`;
        } else if (isCancelled) {
            statusBadge = `<span class="badge badge-error">Cancelled</span>`;
        }

        let actions = '-';
        if (isOpen) {
            actions = `
                <button class="btn btn-secondary btn-icon" onclick="executeLotteryDraw(${draw.id})" style="padding: 4px 8px; font-size: 11px; margin-right: 4px; background: rgba(0, 229, 255, 0.1); color: var(--accent-cyan); border-color: rgba(0, 229, 255, 0.2);">Draw Winner</button>
                <button class="btn btn-ban" onclick="deleteLotteryDraw(${draw.id})" style="padding: 4px 8px; font-size: 11px;">Cancel</button>
            `;
        }

        const formattedDate = new Date(draw.draw_time).toLocaleString();
        const fillPercent = ((draw.joined_tickets / draw.max_tickets) * 100).toFixed(0);

        return `
            <tr>
                <td><strong>#${draw.id}</strong></td>
                <td>
                    <div style="font-weight: 600; color: var(--text-main);">${draw.title}</div>
                </td>
                <td>₹${draw.ticket_price}</td>
                <td>
                    <div style="font-size:11px;">${draw.joined_tickets} / ${draw.max_tickets}</div>
                    <div style="width: 80px; height: 4px; background: rgba(255,255,255,0.05); border-radius: 2px; overflow: hidden; margin-top: 4px;">
                        <div style="width: ${fillPercent}%; height: 100%; background: var(--primary);"></div>
                    </div>
                </td>
                <td><strong>₹${draw.prize_pool}</strong></td>
                <td>${draw.win_percentage}%</td>
                <td>${draw.forced_winning_number ? `<code style="font-family: monospace; font-size: 11px; color: var(--text-main); font-weight: 600;">${draw.forced_winning_number}</code>` : '<span class="text-muted">-</span>'}</td>
                <td style="font-size: 12px; color: var(--text-muted);">${formattedDate}</td>
                <td>${statusBadge}</td>
                <td><code style="font-family: monospace; font-size: 12px; color: var(--accent-emerald); font-weight: bold;">${draw.winning_number || '-'}</code></td>
                <td>
                    <div style="display: flex; gap: 4px;">
                        ${actions}
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

async function executeLotteryDraw(id) {
    const forcedNumberInput = prompt("Enter a specific ticket number to force as the winner (optional, leave blank for random/percentage-based draw):");
    if (forcedNumberInput === null) return; // Admin cancelled the prompt

    if (!confirm("Are you sure you want to execute this lucky draw and select a winner? This action will credit the user's winning balance immediately and notify all participants!")) return;

    try {
        let url = `${API_BASE}/admin/lottery/draws/${id}/draw`;
        if (forcedNumberInput.trim()) {
            url += `?forced_number=${encodeURIComponent(forcedNumberInput.trim())}`;
        }

        const res = await fetch(url, {
            method: 'POST'
        });
        if (!res.ok) throw new Error(await res.text());

        const data = await res.json();
        if (data.winner_user_id) {
            showToast(`Draw executed! Winner ticket: ${data.winning_ticket}. Prize: ₹${data.prize_awarded}`);
        } else {
            showToast(`Draw completed with NO winner. Winning number set to: ${data.winning_ticket}.`, false);
        }
        loadLotteryManager();
    } catch (err) {
        showToast("Error drawing winner: " + err.message, true);
    }
}

async function deleteLotteryDraw(id) {
    if (!confirm("Are you sure you want to cancel this lottery draw? This will issue full refunds to all purchased tickets instantly!")) return;

    try {
        const res = await fetch(`${API_BASE}/admin/lottery/draws/${id}`, {
            method: 'DELETE'
        });
        if (!res.ok) throw new Error(await res.text());

        showToast("Lottery Draw cancelled & refunded successfully.");
        loadLotteryManager();
    } catch (err) {
        showToast("Error cancelling lottery: " + err.message, true);
    }
}

window.setupLotteryHandlers = setupLotteryHandlers;
window.loadLotteryManager = loadLotteryManager;
window.renderLotteryTable = renderLotteryTable;
window.executeLotteryDraw = executeLotteryDraw;
window.deleteLotteryDraw = deleteLotteryDraw;

// Mines Engine Functions
async function loadMinesEngineData() {
    try {
        // 1. Load Stats
        const statsRes = await fetch(`${API_BASE}/admin/mines/stats`);
        if (statsRes.ok) {
            const stats = await statsRes.json();
            document.getElementById('mines-stat-bets').innerText = `₹${stats.total_bet_amount.toFixed(2)}`;
            document.getElementById('mines-stat-winnings').innerText = `₹${stats.total_winnings_paid.toFixed(2)}`;
            document.getElementById('mines-stat-profit').innerText = `₹${stats.platform_net_profit.toFixed(2)}`;
            document.getElementById('mines-stat-rtp').innerText = `${stats.payout_ratio.toFixed(2)}%`;

            const profitEl = document.getElementById('mines-stat-profit');
            if (stats.platform_net_profit < 0) {
                profitEl.style.color = 'var(--error)';
            } else {
                profitEl.style.color = 'var(--success)';
            }
        }

        // 2. Load Settings & Maintenance
        const settingsRes = await fetch(`${API_BASE}/admin/mines/settings`);
        if (settingsRes.ok) {
            const settings = await settingsRes.json();
            state.mines_maintenance = settings.maintenance_mode;

            document.getElementById('mines-house-edge').value = settings.house_edge;
            document.getElementById('mines-min-bet').value = settings.min_bet;
            document.getElementById('mines-max-bet').value = settings.max_bet;

            const btn = document.getElementById('btn-mines-maintenance');
            if (btn) {
                btn.innerText = state.mines_maintenance ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.mines_maintenance ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

        // 3. Load RTP Rules
        await loadMinesRtpSettings();

        // 4. Load Logs
        await loadMinesLogs();

    } catch (err) {
        console.error(err);
        showToast("Error updating Mines Engine: " + err.message, true);
    }
}

async function loadMinesRtpSettings() {
    try {
        const res = await fetch(`${API_BASE}/admin/mines/rtp`);
        if (!res.ok) throw new Error("Failed to load Mines RTP rules.");
        const rules = await res.json();
        state.mines_rtp_rules = rules;
        inspectMinesProbability();

        const tbody = document.getElementById('mines-rtp-rules-table-body');
        if (!tbody) return;

        if (rules.length === 0) {
            tbody.innerHTML = `<tr><td colspan="4" class="table-placeholder">No custom override rules configured.</td></tr>`;
            return;
        }

        tbody.innerHTML = rules.map(r => `
            <tr>
                <td>₹${r.min_amount} – ₹${r.max_amount}</td>
                <td>${(r.win_rate * 100).toFixed(0)}% Safe Click</td>
                <td>
                    <span class="badge ${r.enabled ? 'badge-success' : 'badge-neutral'}">
                        ${r.enabled ? 'Active' : 'Disabled'}
                    </span>
                </td>
                <td>
                    <button class="btn btn-secondary" onclick="deleteMinesRtpRule(${r.id})" style="padding: 4px 8px; font-size: 11px; background: var(--error); color: #fff; border: none;">Delete</button>
                </td>
            </tr>
        `).join('');
    } catch (err) {
        console.error(err);
    }
}

async function deleteMinesRtpRule(id) {
    if (!confirm("Are you sure you want to delete this safety override rule?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/mines/rtp/${id}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(await res.text());
        showToast("Mines override rule deleted.");
        await loadMinesRtpSettings();
    } catch (err) {
        showToast("Error: " + err.message, true);
    }
}

async function loadMinesLogs() {
    try {
        const res = await fetch(`${API_BASE}/admin/mines/logs`);
        if (!res.ok) throw new Error("Failed to load Mines logs.");
        const logs = await res.json();

        const tbody = document.getElementById('mines-logs-table-body');
        if (!tbody) return;

        if (logs.length === 0) {
            tbody.innerHTML = `<tr><td colspan="9" class="table-placeholder">No game logs found.</td></tr>`;
            return;
        }

        tbody.innerHTML = logs.map(l => {
            const probStr = l.win_probability !== null && l.win_probability !== undefined
                ? `${(l.win_probability * 100).toFixed(0)}%`
                : '-';
            return `
                <tr>
                    <td>${l.id}</td>
                    <td>
                        <strong style="cursor: pointer; color: var(--primary);" onclick="viewUserDetails(${l.user_id})">${l.user_name || 'Anonymous'}</strong>
                        <span class="text-muted" style="display:block; font-size:10px;">${l.user_phone}</span>
                    </td>
                    <td>₹${l.bet_amount.toFixed(2)}</td>
                    <td>${l.mines_count}</td>
                    <td>${l.multiplier.toFixed(2)}x</td>
                    <td>₹${l.win_amount.toFixed(2)}</td>
                    <td><span class="badge badge-info">${probStr}</span></td>
                    <td>
                        <span class="badge ${l.result_type === 'WON' ? 'badge-success' : l.result_type === 'LOST' ? 'badge-error' : 'badge-info'}">
                            ${l.result_type}
                        </span>
                    </td>
                    <td>${new Date(l.created_at).toLocaleString()}</td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
    }
}

function setupMinesHandlers() {
    // Probability Calculator listeners
    const inspectMinesBet = document.getElementById('inspect-mines-bet');
    const inspectMinesCount = document.getElementById('inspect-mines-count');
    if (inspectMinesBet) inspectMinesBet.addEventListener('input', inspectMinesProbability);
    if (inspectMinesCount) inspectMinesCount.addEventListener('change', inspectMinesProbability);

    // Maintenance Lock Button
    const btnMaintenance = document.getElementById('btn-mines-maintenance');
    if (btnMaintenance) {
        btnMaintenance.addEventListener('click', async () => {
            const nextState = !state.mines_maintenance;
            btnMaintenance.disabled = true;
            try {
                const res = await fetch(`${API_BASE}/admin/mines/maintenance?enabled=${nextState}`, { method: 'POST' });
                if (!res.ok) throw new Error("Failed to update maintenance mode.");
                const data = await res.json();
                state.mines_maintenance = data.maintenance_mode;
                btnMaintenance.innerText = state.mines_maintenance ? "Unlock Game Access" : "Lock Game Access";
                btnMaintenance.style.backgroundColor = state.mines_maintenance ? 'var(--success)' : 'var(--error)';
                showToast(state.mines_maintenance ? "Mines game LOCKED for maintenance!" : "Mines game unlocked!");
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btnMaintenance.disabled = false;
            }
        });
    }

    // General Settings Form
    const settingsForm = document.getElementById('mines-settings-form');
    if (settingsForm) {
        settingsForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const houseEdge = parseFloat(document.getElementById('mines-house-edge').value);
            const minBet = parseFloat(document.getElementById('mines-min-bet').value);
            const maxBet = parseFloat(document.getElementById('mines-max-bet').value);

            const btn = settingsForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            try {
                const res = await fetch(`${API_BASE}/admin/mines/settings`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        house_edge: houseEdge,
                        min_bet: minBet,
                        max_bet: maxBet,
                        maintenance_mode: !!state.mines_maintenance
                    })
                });
                if (!res.ok) throw new Error(await res.text());
                showToast("Mines settings updated successfully!");
                await loadMinesEngineData();
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btn.disabled = false;
            }
        });
    }

    // RTP Override Form
    const rtpForm = document.getElementById('mines-rtp-create-form');
    if (rtpForm) {
        rtpForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const minBet = parseFloat(document.getElementById('mines-rtp-create-min').value);
            const maxBet = parseFloat(document.getElementById('mines-rtp-create-max').value);
            const winRate = parseFloat(document.getElementById('mines-rtp-create-winrate').value);

            const btn = rtpForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Creating...";
            try {
                const res = await fetch(`${API_BASE}/admin/mines/rtp`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        min_amount: minBet,
                        max_amount: maxBet,
                        win_rate: winRate,
                        enabled: true
                    })
                });
                if (!res.ok) throw new Error(await res.text());
                showToast("Mines safety override rule added!");
                rtpForm.reset();
                await loadMinesRtpSettings();
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Create Mines Override Rule";
            }
        });
    }
}

// Plinko Engine Functions
async function loadPlinkoEngineData() {
    try {
        // 1. Load Stats
        const statsRes = await fetch(`${API_BASE}/admin/plinko/stats`);
        if (statsRes.ok) {
            const stats = await statsRes.json();
            document.getElementById('plinko-stat-bets').innerText = `₹${stats.total_bet_amount.toFixed(2)}`;
            document.getElementById('plinko-stat-winnings').innerText = `₹${stats.total_winnings_paid.toFixed(2)}`;
            document.getElementById('plinko-stat-profit').innerText = `₹${stats.platform_net_profit.toFixed(2)}`;
            document.getElementById('plinko-stat-rtp').innerText = `${stats.payout_ratio.toFixed(2)}%`;

            const profitEl = document.getElementById('plinko-stat-profit');
            if (stats.platform_net_profit < 0) {
                profitEl.style.color = 'var(--error)';
            } else {
                profitEl.style.color = 'var(--success)';
            }
        }

        // 2. Load Settings & Maintenance
        const settingsRes = await fetch(`${API_BASE}/admin/plinko/settings`);
        if (settingsRes.ok) {
            const settings = await settingsRes.json();
            state.plinko_maintenance = settings.maintenance_mode;

            document.getElementById('plinko-min-bet').value = settings.min_bet;
            document.getElementById('plinko-max-bet').value = settings.max_bet;

            const btn = document.getElementById('btn-plinko-maintenance');
            if (btn) {
                btn.innerText = state.plinko_maintenance ? "Unlock Game Access" : "Lock Game Access";
                btn.style.backgroundColor = state.plinko_maintenance ? 'var(--success)' : 'var(--error)';
                btn.style.color = '#fff';
            }
        }

        // 3. Load RTP Rules
        await loadPlinkoRtpSettings();

        // 4. Load Logs
        await loadPlinkoLogs();

    } catch (err) {
        console.error(err);
        showToast("Error updating Plinko Engine: " + err.message, true);
    }
}

async function loadPlinkoRtpSettings() {
    try {
        const res = await fetch(`${API_BASE}/admin/plinko/rtp`);
        if (!res.ok) throw new Error("Failed to load Plinko RTP rules.");
        const rules = await res.json();
        state.plinko_rtp_rules = rules;
        inspectPlinkoProbability();

        const tbody = document.getElementById('plinko-rtp-rules-table-body');
        if (!tbody) return;

        if (rules.length === 0) {
            tbody.innerHTML = `<tr><td colspan="4" class="table-placeholder">No custom override rules configured.</td></tr>`;
            return;
        }

        tbody.innerHTML = rules.map(r => `
            <tr>
                <td>₹${r.min_amount} – ₹${r.max_amount}</td>
                <td>Rows: ${r.rows} (${r.mode})</td>
                <td style="font-family:monospace; font-size:10px;">${r.probability_json}</td>
                <td>
                    <button class="btn btn-secondary" onclick="deletePlinkoRtpRule(${r.id})" style="padding: 4px 8px; font-size: 11px; background: var(--error); color: #fff; border: none;">Delete</button>
                </td>
            </tr>
        `).join('');
    } catch (err) {
        console.error(err);
    }
}

async function deletePlinkoRtpRule(id) {
    if (!confirm("Are you sure you want to delete this Plinko RTP override?")) return;
    try {
        const res = await fetch(`${API_BASE}/admin/plinko/rtp/${id}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(await res.text());
        showToast("Plinko override rule deleted.");
        await loadPlinkoRtpSettings();
    } catch (err) {
        showToast("Error: " + err.message, true);
    }
}

async function loadPlinkoLogs() {
    try {
        const res = await fetch(`${API_BASE}/admin/plinko/logs`);
        if (!res.ok) throw new Error("Failed to load Plinko logs.");
        const logs = await res.json();

        const tbody = document.getElementById('plinko-logs-table-body');
        if (!tbody) return;

        if (logs.length === 0) {
            tbody.innerHTML = `<tr><td colspan="9" class="table-placeholder">No game logs found.</td></tr>`;
            return;
        }

        tbody.innerHTML = logs.map(l => {
            const probStr = l.win_probability !== null && l.win_probability !== undefined
                ? `${(l.win_probability * 100).toFixed(2)}%`
                : '-';
            return `
                <tr>
                    <td>${l.id}</td>
                    <td>
                        <strong style="cursor: pointer; color: var(--primary);" onclick="viewUserDetails(${l.user_id})">${l.user_name || 'Anonymous'}</strong>
                        <span class="text-muted" style="display:block; font-size:10px;">${l.user_phone}</span>
                    </td>
                    <td>₹${l.bet_amount.toFixed(2)}</td>
                    <td>${l.rows}</td>
                    <td>${l.mode}</td>
                    <td>${l.multiplier.toFixed(2)}x</td>
                    <td>₹${l.win_amount.toFixed(2)}</td>
                    <td><span class="badge badge-info">${probStr}</span></td>
                    <td>${new Date(l.created_at).toLocaleString()}</td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
    }
}

function setupPlinkoHandlers() {
    // Probability Calculator listeners
    const inspectPlinkoBet = document.getElementById('inspect-plinko-bet');
    const inspectPlinkoRows = document.getElementById('inspect-plinko-rows');
    const inspectPlinkoMode = document.getElementById('inspect-plinko-mode');
    if (inspectPlinkoBet) inspectPlinkoBet.addEventListener('input', inspectPlinkoProbability);
    if (inspectPlinkoRows) inspectPlinkoRows.addEventListener('change', inspectPlinkoProbability);
    if (inspectPlinkoMode) inspectPlinkoMode.addEventListener('change', inspectPlinkoProbability);

    // Maintenance Lock Button
    const btnMaintenance = document.getElementById('btn-plinko-maintenance');
    if (btnMaintenance) {
        btnMaintenance.addEventListener('click', async () => {
            const nextState = !state.plinko_maintenance;
            btnMaintenance.disabled = true;
            try {
                const res = await fetch(`${API_BASE}/admin/plinko/maintenance?enabled=${nextState}`, { method: 'POST' });
                if (!res.ok) throw new Error("Failed to update maintenance mode.");
                const data = await res.json();
                state.plinko_maintenance = data.maintenance_mode;
                btnMaintenance.innerText = state.plinko_maintenance ? "Unlock Game Access" : "Lock Game Access";
                btnMaintenance.style.backgroundColor = state.plinko_maintenance ? 'var(--success)' : 'var(--error)';
                showToast(state.plinko_maintenance ? "Plinko game LOCKED for maintenance!" : "Plinko game unlocked!");
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btnMaintenance.disabled = false;
            }
        });
    }

    // General Settings Form
    const settingsForm = document.getElementById('plinko-settings-form');
    if (settingsForm) {
        settingsForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const minBet = parseFloat(document.getElementById('plinko-min-bet').value);
            const maxBet = parseFloat(document.getElementById('plinko-max-bet').value);

            const btn = settingsForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            try {
                const res = await fetch(`${API_BASE}/admin/plinko/settings`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        min_bet: minBet,
                        max_bet: maxBet,
                        maintenance_mode: !!state.plinko_maintenance
                    })
                });
                if (!res.ok) throw new Error(await res.text());
                showToast("Plinko settings updated successfully!");
                await loadPlinkoEngineData();
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btn.disabled = false;
            }
        });
    }

    // RTP Override Form
    const rtpForm = document.getElementById('plinko-rtp-create-form');
    if (rtpForm) {
        rtpForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const minBet = parseFloat(document.getElementById('plinko-rtp-create-min').value);
            const maxBet = parseFloat(document.getElementById('plinko-rtp-create-max').value);
            const rows = parseInt(document.getElementById('plinko-rtp-create-rows').value);
            const mode = document.getElementById('plinko-rtp-create-mode').value;
            const rawJson = document.getElementById('plinko-rtp-create-json').value.trim();

            if (isNaN(minBet) || isNaN(maxBet) || isNaN(rows) || !rawJson) {
                showToast("Please fill all fields.", true);
                return;
            }

            const btn = rtpForm.querySelector('button[type="submit"]');
            btn.disabled = true;
            btn.innerText = "Creating...";

            try {
                // validate json
                const parsed = JSON.parse(rawJson);
                if (Array.isArray(parsed)) {
                    if (parsed.length !== rows + 1) {
                        throw new Error(`List must contain exactly ${rows + 1} weights/probabilities.`);
                    }
                } else if (typeof parsed === 'object') {
                    if (Object.keys(parsed).length !== rows + 1) {
                        throw new Error(`Object must map exactly ${rows + 1} bucket indices.`);
                    }
                } else {
                    throw new Error("Must be a list or object mapping indices to weights.");
                }

                const res = await fetch(`${API_BASE}/admin/plinko/rtp`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        min_amount: minBet,
                        max_amount: maxBet,
                        rows: rows,
                        mode: mode,
                        probability_json: JSON.stringify(parsed),
                        enabled: true
                    })
                });
                if (!res.ok) throw new Error(await res.text());
                showToast("Plinko RTP override rule added!");
                rtpForm.reset();
                await loadPlinkoRtpSettings();
            } catch (err) {
                showToast("Error: " + err.message, true);
            } finally {
                btn.disabled = false;
                btn.innerText = "Create Plinko Override Rule";
            }
        });
    }
}

window.setupMinesHandlers = setupMinesHandlers;
window.loadMinesEngineData = loadMinesEngineData;
window.loadMinesRtpSettings = loadMinesRtpSettings;
window.deleteMinesRtpRule = deleteMinesRtpRule;
window.loadMinesLogs = loadMinesLogs;

window.setupPlinkoHandlers = setupPlinkoHandlers;
window.loadPlinkoEngineData = loadPlinkoEngineData;
window.loadPlinkoRtpSettings = loadPlinkoRtpSettings;
window.deletePlinkoRtpRule = deletePlinkoRtpRule;
window.loadPlinkoLogs = loadPlinkoLogs;

async function loadUserGameLogs(userId) {
    const tbody = document.getElementById('user-game-logs-tbody');
    if (!tbody) return;

    try {
        const res = await fetch(`${API_BASE}/admin/users/${userId}/game-logs`);
        if (!res.ok) throw new Error(await res.text());
        const logs = await res.json();

        if (logs.length === 0) {
            tbody.innerHTML = `<tr><td colspan="7" class="table-placeholder">No games played yet.</td></tr>`;
            return;
        }

        tbody.innerHTML = logs.map(l => {
            const dateStr = new Date(l.created_at).toLocaleString();
            const winStyle = l.win_amount > 0 ? 'color: var(--success); font-weight: 600;' : 'color: var(--text-muted);';
            const multStr = l.multiplier !== null && l.multiplier !== undefined ? `${l.multiplier.toFixed(2)}x` : '-';

            let statusClass = 'badge-neutral';
            if (['WON', 'VERIFIED', 'SUCCESS', 'COMPLETED'].includes(l.status)) {
                statusClass = 'badge-success';
            } else if (['LOST', 'FAILED', 'SUSPICIOUS', 'DISQUALIFIED'].includes(l.status)) {
                statusClass = 'badge-error';
            } else if (l.status === 'IN_PROGRESS' || l.status === 'JOINED') {
                statusClass = 'badge-warning';
            }

            return `
                <tr>
                    <td><span class="badge badge-info">${l.game_type}</span></td>
                    <td><strong>${l.title}</strong><div style="font-size: 9px; color: var(--text-muted);">${l.details || ''}</div></td>
                    <td>₹${l.bet_amount.toFixed(2)}</td>
                    <td>${multStr}</td>
                    <td style="${winStyle}">₹${l.win_amount.toFixed(2)}</td>
                    <td><span class="badge ${statusClass}">${l.status}</span></td>
                    <td style="white-space: nowrap;">${dateStr}</td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
        tbody.innerHTML = `<tr><td colspan="7" class="table-placeholder" style="color: var(--error);">Error loading logs: ${err.message}</td></tr>`;
    }
}

async function loadUserWalletTransactions(userId) {
    const tbody = document.getElementById('user-wallet-txs-tbody');
    if (!tbody) return;

    try {
        const res = await fetch(`${API_BASE}/admin/users/${userId}/transactions`);
        if (!res.ok) throw new Error(await res.text());
        const txs = await res.json();

        if (txs.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="table-placeholder">No transactions recorded yet.</td></tr>`;
            return;
        }

        tbody.innerHTML = txs.map(tx => {
            const dateStr = new Date(tx.created_at).toLocaleString();
            let statusBadge = 'badge-warning';
            if (tx.status === 'SUCCESS') statusBadge = 'badge-success';
            if (tx.status === 'FAILED') statusBadge = 'badge-error';

            let typeBadge = 'badge-warning';
            let typeStyle = 'color: var(--warning)';
            let prefix = '-';

            if (tx.type === 'DEPOSIT' || tx.type === 'PRIZE_WIN' || tx.type === 'REFERRAL_BONUS') {
                typeBadge = 'badge-success';
                typeStyle = 'color: var(--success); font-weight: 600;';
                prefix = '+';
            } else if (tx.type === 'WITHDRAWAL' || tx.type === 'ENTRY_FEE') {
                typeBadge = 'badge-error';
                typeStyle = 'color: var(--error);';
                prefix = '-';
            }

            return `
                <tr>
                    <td>#${tx.id}</td>
                    <td>
                        <span class="badge ${typeBadge}">${tx.type}</span>
                    </td>
                    <td style="${typeStyle}">${prefix}₹${tx.amount.toFixed(2)}</td>
                    <td><span class="badge ${statusBadge}">${tx.status}</span></td>
                    <td><span style="font-size: 11px; color: var(--text-muted);">${tx.description || '-'}</span></td>
                    <td style="white-space: nowrap;">${dateStr}</td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
        tbody.innerHTML = `<tr><td colspan="6" class="table-placeholder" style="color: var(--error);">Error loading transactions: ${err.message}</td></tr>`;
    }
}

function inspectMinesProbability() {
    const betVal = parseFloat(document.getElementById('inspect-mines-bet').value);
    const countVal = parseInt(document.getElementById('inspect-mines-count').value);

    if (isNaN(betVal) || isNaN(countVal)) return;

    const rtpRules = state.mines_rtp_rules || [];
    const activeRule = rtpRules.find(r => r.enabled && r.min_amount <= betVal && betVal <= r.max_amount);

    const resultEl = document.getElementById('inspect-mines-result');
    const reasonEl = document.getElementById('inspect-mines-reason');
    if (!resultEl || !reasonEl) return;

    if (activeRule) {
        resultEl.innerText = `${(activeRule.win_rate * 100).toFixed(0)}% Safe Click`;
        reasonEl.innerText = `Override Rule ID #${activeRule.id} active for bet ₹${betVal}. Force-safe chance: ${(activeRule.win_rate * 100).toFixed(0)}%.`;
    } else {
        const defaultProb = ((25 - countVal) / 25) * 100;
        resultEl.innerText = `${defaultProb.toFixed(0)}% Safe Click`;
        reasonEl.innerText = `No active override rule. Default safe cell reveal chance is (25 - ${countVal}) / 25 = ${defaultProb.toFixed(0)}% on first click.`;
    }
}

function inspectPlinkoProbability() {
    const betVal = parseFloat(document.getElementById('inspect-plinko-bet').value);
    const rowsVal = parseInt(document.getElementById('inspect-plinko-rows').value);
    const modeVal = document.getElementById('inspect-plinko-mode').value;

    if (isNaN(betVal) || isNaN(rowsVal) || !modeVal) return;

    const rtpRules = state.plinko_rtp_rules || [];
    const activeRule = rtpRules.find(r => r.enabled && r.min_amount <= betVal && betVal <= r.max_amount && r.rows === rowsVal && r.mode.toLowerCase() === modeVal.toLowerCase());

    const resultEl = document.getElementById('inspect-plinko-result');
    const reasonEl = document.getElementById('inspect-plinko-reason');
    if (!resultEl || !reasonEl) return;

    if (activeRule) {
        try {
            const weights = JSON.parse(activeRule.probability_json);
            let probs = [];
            if (Array.isArray(weights)) {
                const sum = weights.reduce((a, b) => a + b, 0);
                probs = weights.map(w => `${((w / sum) * 100).toFixed(1)}%`);
            } else if (typeof weights === 'object') {
                const sum = Object.values(weights).reduce((a, b) => a + b, 0);
                probs = Object.keys(weights).map(k => `Bucket ${k}: ${((weights[k] / sum) * 100).toFixed(1)}%`);
            }
            resultEl.innerText = JSON.stringify(probs);
            reasonEl.innerText = `Override Rule ID #${activeRule.id} active. Custom weighted probability distribution is applied.`;
        } catch (e) {
            resultEl.innerText = activeRule.probability_json;
            reasonEl.innerText = `Error parsing override: ${e.message}`;
        }
    } else {
        function comb(n, k) {
            if (k < 0 || k > n) return 0;
            if (k === 0 || k === n) return 1;
            let res = 1;
            for (let i = 1; i <= k; i++) {
                res = res * (n - i + 1) / i;
            }
            return res;
        }
        let probs = [];
        const factor = Math.pow(0.5, rowsVal);
        for (let k = 0; k <= rowsVal; k++) {
            const prob = comb(rowsVal, k) * factor * 100;
            probs.push(`${prob.toFixed(1)}%`);
        }
        resultEl.innerText = JSON.stringify(probs);
        reasonEl.innerText = `No active override rule. Standard binomial distribution applies (0.5 ^ ${rowsVal}).`;
    }
}

window.inspectMinesProbability = inspectMinesProbability;
window.inspectPlinkoProbability = inspectPlinkoProbability;
window.loadUserGameLogs = loadUserGameLogs;









