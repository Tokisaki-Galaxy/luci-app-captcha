'use strict';
'require view';
'require form';
'require ui';
'require uci';
'require rpc';

var callGetConfig = rpc.declare({
	object: 'captcha',
	method: 'getConfig',
	expect: { }
});

var callSetConfig = rpc.declare({
	object: 'captcha',
	method: 'setConfig',
	params: [
		'enabled', 'provider',
		'local_length', 'local_noise', 'local_case_sensitive',
		'turnstile_sitekey', 'turnstile_secret',
		'hcaptcha_sitekey', 'hcaptcha_secret',
		'ip_whitelist_enabled', 'ip_whitelist',
		'rate_limit_enabled', 'rate_limit_max_attempts',
		'rate_limit_window', 'rate_limit_lockout'
	]
});

var callGenerateCaptcha = rpc.declare({
	object: 'captcha',
	method: 'generateCaptcha',
	expect: { }
});

var callGetRateLimitStatus = rpc.declare({
	object: 'captcha',
	method: 'getRateLimitStatus',
	expect: { entries: [] }
});

var callClearRateLimit = rpc.declare({
	object: 'captcha',
	method: 'clearRateLimit',
	params: [ 'ip' ]
});

var callClearAllRateLimits = rpc.declare({
	object: 'captcha',
	method: 'clearAllRateLimits'
});

// CAPTCHA Preview Widget
var CBICaptchaPreview = form.DummyValue.extend({
	renderWidget: function(section_id, option_id, cfgvalue) {
		var provider = uci.get('captcha', 'settings', 'provider') || 'local';
		var containerDiv = E('div', { 'id': 'captcha-preview-container' });

		if (provider !== 'local') {
			containerDiv.appendChild(E('em', {}, 
				_('CAPTCHA preview is only available for local provider. ') +
				_('Cloud providers (Turnstile, hCaptcha) will be rendered on the login page.')
			));
			return containerDiv;
		}

		var previewArea = E('div', { 'id': 'captcha-preview-area', 'style': 'margin: 10px 0; padding: 10px; border: 1px solid #ddd; background: #fafafa; text-align: center;' }, [
			E('em', {}, _('Click "Refresh Preview" to generate a test CAPTCHA'))
		]);

		var refreshBtn = E('button', {
			'class': 'cbi-button cbi-button-action',
			'style': 'margin-top: 10px;',
			'click': ui.createHandlerFn(this, function() {
				previewArea.innerHTML = '<em>' + _('Loading...') + '</em>';
				return callGenerateCaptcha().then(function(res) {
					if (res.svg) {
						previewArea.innerHTML = res.svg;
					} else {
						previewArea.innerHTML = '<em style="color: red;">' + _('Failed to generate CAPTCHA') + '</em>';
					}
				}).catch(function(err) {
					previewArea.innerHTML = '<em style="color: red;">' + _('Error: ') + err.message + '</em>';
				});
			})
		}, _('Refresh Preview'));

		return E('div', {}, [
			previewArea,
			E('br'),
			refreshBtn,
			E('br'),
			E('small', { 'style': 'color: #666;' }, _('This shows what users will see on the login page.'))
		]);
	}
});

// IP Whitelist Widget
var CBIIPWhitelist = form.DynamicList.extend({
	datatype: 'or(ip4addr,ip6addr,cidr4,cidr6)'
});

// Rate Limit Status Widget
var CBIRateLimitStatus = form.DummyValue.extend({
	renderWidget: function(section_id, option_id, cfgvalue) {
		var containerDiv = E('div', { 'id': 'rate-limit-status-container' });
		
		var refreshBtn = E('button', {
			'class': 'cbi-button cbi-button-action',
			'style': 'margin-bottom: 10px;',
			'click': ui.createHandlerFn(this, function() {
				return this.refreshStatus(containerDiv);
			})
		}, _('Refresh'));
		
		var clearAllBtn = E('button', {
			'class': 'cbi-button cbi-button-negative',
			'style': 'margin-left: 10px; margin-bottom: 10px;',
			'click': ui.createHandlerFn(this, function() {
				return callClearAllRateLimits().then(function() {
					ui.addNotification(null, E('p', _('All rate limits cleared.')), 'info');
					return this.refreshStatus(containerDiv);
				}.bind(this));
			})
		}, _('Clear All'));
		
		var statusDiv = E('div', { 'id': 'rate-limit-status-list' }, [
			E('em', {}, _('Click "Refresh" to load rate limit status'))
		]);
		
		return E('div', {}, [
			E('div', {}, [refreshBtn, clearAllBtn]),
			statusDiv
		]);
	},
	
	refreshStatus: function(container) {
		var statusDiv = container.querySelector('#rate-limit-status-list') || container;
		statusDiv.innerHTML = '';
		statusDiv.appendChild(E('em', {}, _('Loading...')));
		
		return callGetRateLimitStatus().then(function(result) {
			statusDiv.innerHTML = '';
			
			if (!result.entries || result.entries.length === 0) {
				statusDiv.appendChild(E('em', {}, _('No rate limit entries.')));
				return;
			}
			
			var table = E('table', { 'class': 'table' }, [
				E('tr', { 'class': 'tr table-titles' }, [
					E('th', { 'class': 'th' }, _('IP Address')),
					E('th', { 'class': 'th' }, _('Failed Attempts')),
					E('th', { 'class': 'th' }, _('Status')),
					E('th', { 'class': 'th' }, _('Actions'))
				])
			]);
			
			result.entries.forEach(function(entry) {
				var status = entry.locked ? 
					_('Locked until ') + new Date(entry.locked_until * 1000).toLocaleString() :
					_('Active');
				var statusClass = entry.locked ? 'color: red;' : '';
				
				var clearBtn = E('button', {
					'class': 'cbi-button cbi-button-remove',
					'click': ui.createHandlerFn(this, function() {
						return callClearRateLimit(entry.ip).then(function() {
							ui.addNotification(null, E('p', _('Rate limit cleared for ') + entry.ip), 'info');
							return this.refreshStatus(container);
						}.bind(this));
					}.bind(this))
				}, _('Clear'));
				
				table.appendChild(E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td' }, entry.ip),
					E('td', { 'class': 'td' }, String(entry.attempts)),
					E('td', { 'class': 'td', 'style': statusClass }, status),
					E('td', { 'class': 'td' }, clearBtn)
				]));
			}.bind(this));
			
			statusDiv.appendChild(table);
		}.bind(this)).catch(function(err) {
			statusDiv.innerHTML = '';
			statusDiv.appendChild(E('em', { 'style': 'color: red;' }, _('Error loading status: ') + err.message));
		});
	}
});

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('captcha'),
			callGetConfig()
		]);
	},

	render: function(data) {
		var m, s, o;

		m = new form.Map('captcha', _('CAPTCHA Authentication'),
			_('Configure CAPTCHA verification for LuCI login. ') +
			_('When enabled, users must complete a CAPTCHA challenge in addition to entering their username and password.'));

		// ================================================================
		// CAPTCHA Settings Section
		// ================================================================
		s = m.section(form.NamedSection, 'settings', 'settings', _('CAPTCHA Settings'),
			_('Choose a CAPTCHA provider and configure its settings.'));
		s.anonymous = true;
		s.addremove = false;

		// Tab 1: Basic Settings
		s.tab('basic', _('Basic'));

		// Tab 2: Provider Settings
		s.tab('provider', _('Provider'));

		// === Basic Tab ===

		// Enable CAPTCHA toggle
		o = s.taboption('basic', form.Flag, 'enabled', _('Enable CAPTCHA'),
			_('Enable CAPTCHA verification for LuCI login. Users must complete a CAPTCHA to log in.'));
		o.rmempty = false;

		// CAPTCHA Provider
		o = s.taboption('basic', form.ListValue, 'provider', _('CAPTCHA Provider'),
			_('Select the CAPTCHA provider. Local SVG CAPTCHA works offline, while cloud providers require internet access.'));
		o.value('local', _('Local SVG CAPTCHA (offline)'));
		o.value('turnstile', _('Cloudflare Turnstile (cloud)'));
		o.value('hcaptcha', _('hCaptcha (cloud)'));
		o.default = 'local';

		// CAPTCHA Preview
		o = s.taboption('basic', CBICaptchaPreview, '_captcha_preview', _('CAPTCHA Preview'),
			_('Preview what the CAPTCHA will look like on the login page.'));

		// === Provider Tab ===

		// --- Local CAPTCHA Settings ---
		o = s.taboption('provider', form.Value, 'local_length', _('CAPTCHA Length'),
			_('Number of characters in the CAPTCHA (3-8).'));
		o.depends('provider', 'local');
		o.default = '4';
		o.datatype = 'range(3,8)';
		o.placeholder = '4';

		o = s.taboption('provider', form.Value, 'local_noise', _('Noise Level'),
			_('Amount of noise lines/dots to add for obfuscation (0-100).'));
		o.depends('provider', 'local');
		o.default = '50';
		o.datatype = 'range(0,100)';
		o.placeholder = '50';

		o = s.taboption('provider', form.Flag, 'local_case_sensitive', _('Case Sensitive'),
			_('Require users to enter the correct case. When disabled, both "ABC" and "abc" are accepted.'));
		o.depends('provider', 'local');
		o.default = '0';
		o.rmempty = false;

		// --- Cloudflare Turnstile Settings ---
		o = s.taboption('provider', form.Value, 'turnstile_sitekey', _('Turnstile Site Key'),
			_('Your Cloudflare Turnstile site key. Get one at https://dash.cloudflare.com/'));
		o.depends('provider', 'turnstile');
		o.placeholder = '0x4AAAAAAA...';

		o = s.taboption('provider', form.Value, 'turnstile_secret', _('Turnstile Secret Key'),
			_('Your Cloudflare Turnstile secret key. Keep this confidential.'));
		o.depends('provider', 'turnstile');
		o.password = true;
		o.placeholder = '0x4AAAAAAA...';

		// Turnstile setup instructions
		o = s.taboption('provider', form.DummyValue, '_turnstile_info', _('Setup Instructions'));
		o.depends('provider', 'turnstile');
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<div style="color: #666; font-size: 12px; padding: 10px; background: #f9f9f9; border-radius: 4px;">' +
				'<strong>' + _('To set up Cloudflare Turnstile:') + '</strong><br><br>' +
				'1. ' + _('Go to Cloudflare Dashboard → Turnstile') + '<br>' +
				'2. ' + _('Create a new site and get your Site Key and Secret Key') + '<br>' +
				'3. ' + _('Add your router\'s domain/IP to the allowed domains') + '<br>' +
				'4. ' + _('Enter the keys above') + '<br><br>' +
				'<a href="https://dash.cloudflare.com/" target="_blank">' + _('Open Cloudflare Dashboard') + ' →</a>' +
				'</div>';
		};

		// --- hCaptcha Settings ---
		o = s.taboption('provider', form.Value, 'hcaptcha_sitekey', _('hCaptcha Site Key'),
			_('Your hCaptcha site key. Get one at https://www.hcaptcha.com/'));
		o.depends('provider', 'hcaptcha');
		o.placeholder = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';

		o = s.taboption('provider', form.Value, 'hcaptcha_secret', _('hCaptcha Secret Key'),
			_('Your hCaptcha secret key. Keep this confidential.'));
		o.depends('provider', 'hcaptcha');
		o.password = true;
		o.placeholder = '0x...';

		// hCaptcha setup instructions
		o = s.taboption('provider', form.DummyValue, '_hcaptcha_info', _('Setup Instructions'));
		o.depends('provider', 'hcaptcha');
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<div style="color: #666; font-size: 12px; padding: 10px; background: #f9f9f9; border-radius: 4px;">' +
				'<strong>' + _('To set up hCaptcha:') + '</strong><br><br>' +
				'1. ' + _('Create an account at hCaptcha.com') + '<br>' +
				'2. ' + _('Add a new site and get your Site Key and Secret Key') + '<br>' +
				'3. ' + _('Configure your allowed domains') + '<br>' +
				'4. ' + _('Enter the keys above') + '<br><br>' +
				'<a href="https://www.hcaptcha.com/" target="_blank">' + _('Open hCaptcha Dashboard') + ' →</a>' +
				'</div>';
		};

		// ================================================================
		// Security Settings Section
		// ================================================================
		var securitySection = m.section(form.NamedSection, 'settings', 'settings', _('Security Settings'),
			_('Configure IP whitelisting and brute force protection.'));
		securitySection.anonymous = true;
		securitySection.addremove = false;

		// Tab 1: IP Whitelist
		securitySection.tab('whitelist', _('IP Whitelist'));

		// Tab 2: Brute Force Protection
		securitySection.tab('bruteforce', _('Brute Force Protection'));

		// === IP Whitelist Tab ===

		o = securitySection.taboption('whitelist', form.Flag, 'ip_whitelist_enabled', _('Enable IP Whitelist'),
			_('Allow specific IP addresses or networks to bypass CAPTCHA verification.'));
		o.rmempty = false;

		o = securitySection.taboption('whitelist', CBIIPWhitelist, 'ip_whitelist', _('Trusted IP Addresses'),
			_('Enter IP addresses or CIDR ranges that should bypass CAPTCHA.'));
		o.depends('ip_whitelist_enabled', '1');
		o.placeholder = '192.168.1.0/24';

		o = securitySection.taboption('whitelist', form.DummyValue, '_whitelist_examples', _('Examples'));
		o.depends('ip_whitelist_enabled', '1');
		o.rawhtml = true;
		o.cfgvalue = function() {
			return '<div style="color: #666; font-size: 12px;">' +
				'<strong>' + _('Single IP:') + '</strong> 192.168.1.100<br>' +
				'<strong>' + _('Subnet:') + '</strong> 192.168.1.0/24<br>' +
				'<strong>' + _('Larger network:') + '</strong> 10.0.0.0/8<br>' +
				'<strong>' + _('IPv6:') + '</strong> fd00::/8' +
				'</div>';
		};

		// === Brute Force Protection Tab ===

		o = securitySection.taboption('bruteforce', form.Flag, 'rate_limit_enabled', _('Enable Brute Force Protection'),
			_('Temporarily block IPs with too many failed CAPTCHA attempts.'));
		o.rmempty = false;

		o = securitySection.taboption('bruteforce', form.Value, 'rate_limit_max_attempts', _('Max Failed Attempts'),
			_('Number of failed attempts before blocking.'));
		o.depends('rate_limit_enabled', '1');
		o.default = '5';
		o.datatype = 'range(1,100)';
		o.placeholder = '5';

		o = securitySection.taboption('bruteforce', form.Value, 'rate_limit_window', _('Detection Window (seconds)'),
			_('Time period for counting failed attempts.'));
		o.depends('rate_limit_enabled', '1');
		o.default = '60';
		o.datatype = 'range(1,3600)';
		o.placeholder = '60';

		o = securitySection.taboption('bruteforce', form.Value, 'rate_limit_lockout', _('Lockout Duration (seconds)'),
			_('How long to block an IP after exceeding max attempts.'));
		o.depends('rate_limit_enabled', '1');
		o.default = '300';
		o.datatype = 'range(1,86400)';
		o.placeholder = '300';

		o = securitySection.taboption('bruteforce', CBIRateLimitStatus, '_rate_limit_status', _('Blocked IPs'),
			_('View and manage blocked IP addresses.'));
		o.depends('rate_limit_enabled', '1');

		return m.render();
	}
});
