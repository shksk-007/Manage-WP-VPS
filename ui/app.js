document.addEventListener('DOMContentLoaded', () => {
    
    const API_URL = 'api.php';
    
    // Elements
    const authOverlay = document.getElementById('auth-overlay');
    const appContainer = document.getElementById('app-container');
    const loginForm = document.getElementById('login-form');
    const loginError = document.getElementById('login-error');
    
    // Check Auth Status on load
    fetchAuthStatus();

    // Login Form Submit
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const fd = new FormData();
        fd.append('action', 'login');
        fd.append('username', document.getElementById('username').value);
        fd.append('password', document.getElementById('password').value);

        try {
            const res = await fetch(API_URL, { method: 'POST', body: fd });
            const data = await res.json();
            
            if (data.success) {
                showApp();
                loadSites();
            } else {
                loginError.textContent = data.error || 'Login failed';
            }
        } catch (err) {
            loginError.textContent = 'Network error';
        }
    });

    // Logout
    document.getElementById('logout-btn').addEventListener('click', async () => {
        const fd = new FormData();
        fd.append('action', 'logout');
        await fetch(API_URL, { method: 'POST', body: fd });
        showLogin();
    });

    async function fetchAuthStatus() {
        try {
            const fd = new FormData();
            fd.append('action', 'check_auth');
            const res = await fetch(API_URL, { method: 'POST', body: fd });
            const data = await res.json();
            
            if (data.authenticated) {
                showApp();
                loadSites();
            } else {
                showLogin();
            }
        } catch (e) {
            showLogin();
        }
    }

    function showApp() {
        authOverlay.classList.remove('active');
        appContainer.classList.remove('hidden');
    }

    function showLogin() {
        authOverlay.classList.add('active');
        appContainer.classList.add('hidden');
    }

    // Navigation Logic
    const menuItems = document.querySelectorAll('.menu-item');
    const views = document.querySelectorAll('.view');
    const pageTitle = document.getElementById('page-title');

    menuItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            
            // Update Active State
            menuItems.forEach(m => m.classList.remove('active'));
            item.classList.add('active');

            // Switch View
            const targetId = `view-${item.dataset.target}`;
            views.forEach(v => v.classList.add('hidden'));
            document.getElementById(targetId).classList.remove('hidden');

            // Update Title
            pageTitle.textContent = item.textContent.trim();
            
            if(item.dataset.target === 'sites') loadSites();
            if(item.dataset.target === 'activity') {
                runCommand('activity', [], 'Activity Logs', document.getElementById('terminal-activity'));
            }
        });
    });

    // Modals
    const btnCreateSite = document.getElementById('btn-create-site');
    const modalCreate = document.getElementById('modal-create');
    const modalTerminal = document.getElementById('modal-terminal');
    const closeBtns = document.querySelectorAll('.close-modal');

    btnCreateSite.addEventListener('click', () => modalCreate.classList.remove('hidden'));
    
    closeBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            modalCreate.classList.add('hidden');
            modalTerminal.classList.add('hidden');
        });
    });

    // Create Site Form Submit
    document.getElementById('form-create-site').addEventListener('submit', async (e) => {
        e.preventDefault();
        const dom = document.getElementById('new-domain').value;
        const usr = document.getElementById('new-admin').value;
        const eml = document.getElementById('new-email').value;
        const pwd = document.getElementById('new-pass').value;

        modalCreate.classList.add('hidden');
        
        runCommand('create', [
            `--domain=${dom}`, 
            `--admin=${usr}`, 
            `--email=${eml}`, 
            `--pass=${pwd}`, 
            `--force`
        ], `Creating Site: ${dom}`);
        
        // Wait and reload sites
        setTimeout(loadSites, 15000); // Give it some time
    });

    // Run Terminal Command (Generic Wrapper)
    async function runCommand(command, args = [], title = 'Command Output', targetElement = null) {
        
        let outElement = targetElement;
        
        if (!targetElement) {
            modalTerminal.classList.remove('hidden');
            document.getElementById('term-title').textContent = title;
            outElement = document.getElementById('term-output');
        }

        outElement.textContent = 'Executing...\n';

        const fd = new FormData();
        fd.append('action', 'execute');
        fd.append('command', command);
        args.forEach(arg => fd.append('args[]', arg));

        try {
            const res = await fetch(API_URL, { method: 'POST', body: fd });
            const data = await res.json();
            
            if (data.success) {
                outElement.textContent = data.output || 'Command completed with no output.';
            } else {
                outElement.textContent = 'Error: ' + (data.error || 'Unknown error');
            }
        } catch (e) {
            outElement.textContent = 'Request failed.';
        }
    }

    // Specific Actions
    document.getElementById('btn-refresh-sites').addEventListener('click', loadSites);
    
    document.getElementById('btn-run-doctor').addEventListener('click', () => {
        runCommand('doctor', [], 'System Health', document.getElementById('terminal-server'));
    });

    document.getElementById('btn-run-security').addEventListener('click', () => {
        runCommand('security', [], 'Security Scan', document.getElementById('terminal-security'));
    });

    document.getElementById('btn-refresh-activity').addEventListener('click', () => {
        runCommand('activity', [], 'Activity Logs', document.getElementById('terminal-activity'));
    });

    // Load Sites
    async function loadSites() {
        const sitesList = document.getElementById('sites-list');
        const loader = document.getElementById('sites-loading');
        
        sitesList.innerHTML = '';
        loader.classList.remove('hidden');

        const fd = new FormData();
        fd.append('action', 'execute');
        fd.append('command', 'list');
        
        try {
            const res = await fetch(API_URL, { method: 'POST', body: fd });
            const data = await res.json();
            
            loader.classList.add('hidden');
            
            if (data.success && data.output) {
                // Parse standard wp-host list output
                const lines = data.output.split('\n');
                let foundSites = false;

                lines.forEach(line => {
                    // Very basic parsing, assume domains look like strings with dots
                    if (line.includes('.') && !line.includes('===') && !line.includes('Sites')) {
                        const domain = line.trim();
                        if(domain.length > 3) {
                            foundSites = true;
                            createSiteCard(domain);
                        }
                    }
                });

                if(!foundSites) {
                    sitesList.innerHTML = '<p class="text-muted">No sites found. Create one from the terminal.</p>';
                }

            } else {
                sitesList.innerHTML = '<p class="text-muted">Failed to load sites.</p>';
            }
        } catch (e) {
            loader.classList.add('hidden');
            sitesList.innerHTML = '<p class="text-danger">Network error.</p>';
        }
    }

    let currentManageDomain = '';

    function createSiteCard(domain) {
        const list = document.getElementById('sites-list');
        const card = document.createElement('li');
        card.className = 'site-card';
        card.innerHTML = `
            <div class="site-domain">
                <div class="status-indicator"></div>
                ${domain}
            </div>
            <div class="text-muted" style="font-size: 0.85rem">
                Status: Active &bull; PHP-FPM
            </div>
            <div class="site-actions">
                <button class="btn outline primary manage-btn full-width" data-domain="${domain}">Manage Site</button>
            </div>
        `;
        list.appendChild(card);

        card.querySelector('.manage-btn').addEventListener('click', (e) => {
            openSiteDetail(e.target.dataset.domain);
        });
    }

    // --- Detailed Site View Logic ---
    const viewSites = document.getElementById('view-sites');
    const viewDetail = document.getElementById('view-site-detail');
    const btnBackSites = document.getElementById('btn-back-sites');

    btnBackSites.addEventListener('click', () => {
        viewDetail.classList.add('hidden');
        viewSites.classList.remove('hidden');
    });

    function openSiteDetail(domain) {
        currentManageDomain = domain;
        document.getElementById('detail-domain-title').textContent = domain;
        
        viewSites.classList.add('hidden');
        viewDetail.classList.remove('hidden');
        
        loadBackups(domain);
    }

    document.getElementById('btn-site-login').addEventListener('click', async () => {
        if(!currentManageDomain) return;
        runCommand('login', [currentManageDomain], 'WP-CLI Auto Login', document.getElementById('term-output'));
        modalTerminal.classList.remove('hidden');
        document.getElementById('term-title').textContent = 'Magic Login Link';
    });

    document.getElementById('btn-site-scan').addEventListener('click', () => {
        if(!currentManageDomain) return;
        runCommand('scan', [currentManageDomain], `Security Scan: ${currentManageDomain}`);
    });

    document.getElementById('btn-site-backup').addEventListener('click', () => {
        if(!currentManageDomain) return;
        runCommand('backup', [currentManageDomain], `Backup: ${currentManageDomain}`);
        setTimeout(() => loadBackups(currentManageDomain), 5000);
    });

    document.getElementById('btn-site-logs').addEventListener('click', () => {
        if(!currentManageDomain) return;
        runCommand('logs', [currentManageDomain], `Error Logs: ${currentManageDomain}`, document.getElementById('term-output'));
        modalTerminal.classList.remove('hidden');
        document.getElementById('term-title').textContent = `Error Logs: ${currentManageDomain}`;
    });

    document.getElementById('btn-site-delete').addEventListener('click', () => {
        if(!currentManageDomain) return;
        if(confirm(`WARNING! This will permanently delete ${currentManageDomain}. Are you sure?`)) {
            runCommand('delete', [currentManageDomain], `Delete: ${currentManageDomain}`);
            setTimeout(() => {
                viewDetail.classList.add('hidden');
                viewSites.classList.remove('hidden');
                loadSites();
            }, 3000);
        }
    });

    async function loadBackups(domain) {
        const list = document.getElementById('site-backups-list');
        const loader = document.getElementById('site-backups-loading');
        
        list.innerHTML = '';
        loader.classList.remove('hidden');

        const fd = new FormData();
        fd.append('action', 'execute');
        fd.append('command', 'backups-list');
        fd.append('args[]', domain);

        try {
            const res = await fetch(API_URL, { method: 'POST', body: fd });
            const data = await res.json();
            
            loader.classList.add('hidden');
            
            if (data.success && data.output && data.output.trim() !== '') {
                const backups = data.output.trim().split('\\n');
                backups.forEach(bkp => {
                    const li = document.createElement('li');
                    li.className = 'backup-item';
                    li.innerHTML = `
                        <span><strong>\${bkp}</strong></span>
                        <button class="btn outline restore-btn" data-backup="\${bkp}">Restore</button>
                    `;
                    list.appendChild(li);

                    li.querySelector('.restore-btn').addEventListener('click', (e) => {
                        const targetBkp = e.target.dataset.backup;
                        if(confirm(`Restore backup \${targetBkp} for \${domain}? This overwrites current files and database.`)) {
                            runCommand('restore', [domain, `--backup=\${targetBkp}`, '--force'], `Restoring \${domain}`);
                        }
                    });
                });
            } else {
                list.innerHTML = '<p class="text-muted">No backups found.</p>';
            }
        } catch(e) {
            loader.classList.add('hidden');
            list.innerHTML = '<p class="text-danger">Failed to load backups.</p>';
        }
    }

});
