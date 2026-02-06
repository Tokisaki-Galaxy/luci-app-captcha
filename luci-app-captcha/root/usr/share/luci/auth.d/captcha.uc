// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2024 LuCI CAPTCHA Plugin Contributors
//
// LuCI Authentication Plugin: CAPTCHA Human Verification
//
// This plugin implements CAPTCHA verification as an additional
// authentication factor for LuCI login. Supports local SVG CAPTCHA,
// Cloudflare Turnstile, and hCaptcha.

// Validate IP address (IPv4 or IPv6)
function is_valid_ip(ip) {
	if (!ip || ip == '')
		return false;
	// IPv4 pattern
	if (match(ip, /^(\d{1,3}\.){3}\d{1,3}$/)) {
		let parts = split(ip, '.');
		for (let i = 0; i < length(parts); i++) {
			if (int(parts[i]) > 255) return false;
		}
		return true;
	}
	// IPv4 CIDR pattern
	if (match(ip, /^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$/)) {
		let cidr_parts = split(ip, '/');
		let prefix = int(cidr_parts[1]);
		if (prefix < 0 || prefix > 32) return false;
		let ip_parts = split(cidr_parts[0], '.');
		for (let i = 0; i < length(ip_parts); i++) {
			if (int(ip_parts[i]) > 255) return false;
		}
		return true;
	}
	// IPv6 pattern (simplified)
	if (match(ip, /^[0-9a-fA-F:]+$/) && index(ip, ':') >= 0)
		return true;
	// IPv6 CIDR pattern
	if (match(ip, /^[0-9a-fA-F:]+\/\d{1,3}$/) && index(ip, ':') >= 0) {
		let cidr_parts = split(ip, '/');
		let prefix = int(cidr_parts[1]);
		if (prefix < 0 || prefix > 128) return false;
		return true;
	}
	return false;
}

// Check if an IP is in a CIDR range
function ip_in_cidr(ip, cidr) {
	let parts = split(cidr, '/');
	let network_ip = parts[0];
	let prefix = (length(parts) > 1) ? int(parts[1]) : 32;
	
	// For IPv6, fall back to exact string comparison
	if (!match(ip, /^(\d{1,3}\.){3}\d{1,3}$/))
		return ip == network_ip;
	
	if (!match(network_ip, /^(\d{1,3}\.){3}\d{1,3}$/))
		return false;
	
	let ip_parts = split(ip, '.');
	let net_parts = split(network_ip, '.');
	
	let ip_int = (int(ip_parts[0]) << 24) | (int(ip_parts[1]) << 16) | (int(ip_parts[2]) << 8) | int(ip_parts[3]);
	let net_int = (int(net_parts[0]) << 24) | (int(net_parts[1]) << 16) | (int(net_parts[2]) << 8) | int(net_parts[3]);
	
	let mask = 0;
	if (prefix > 0) {
		mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
	}
	
	return ((ip_int & mask) == (net_int & mask));
}

// Check if IP is in whitelist
function is_ip_whitelisted(ip) {
	let uci = require('uci');
	let ctx = uci.cursor();
	
	let whitelist_enabled = ctx.get('captcha', 'settings', 'ip_whitelist_enabled');
	if (whitelist_enabled != '1')
		return false;
	
	let settings = ctx.get_all('captcha', 'settings');
	if (!settings || !settings.ip_whitelist)
		return false;
	
	let ips = settings.ip_whitelist;
	if (type(ips) == 'string') {
		ips = [ips];
	}
	
	for (let entry in ips) {
		if (!entry || entry == '')
			continue;
		if (index(entry, '/') >= 0) {
			if (ip_in_cidr(ip, entry))
				return true;
		} else {
			if (ip == entry)
				return true;
		}
	}
	
	return false;
}

// Rate limit state file
const RATE_LIMIT_FILE = '/tmp/captcha_rate_limit.json';

function load_rate_limit_state() {
	let fs = require('fs');
	let content = fs.readfile(RATE_LIMIT_FILE);
	if (!content)
		return {};
	
	let state = json(content);
	if (!state)
		return {};
	
	return state;
}

function save_rate_limit_state(state) {
	let fs = require('fs');
	fs.writefile(RATE_LIMIT_FILE, sprintf('%J', state));
}

function check_rate_limit(ip) {
	let uci = require('uci');
	let ctx = uci.cursor();
	
	let rate_limit_enabled = ctx.get('captcha', 'settings', 'rate_limit_enabled');
	if (rate_limit_enabled != '1')
		return { allowed: true, remaining: -1, locked_until: 0 };
	
	let max_attempts = int(ctx.get('captcha', 'settings', 'rate_limit_max_attempts') || '5');
	let window = int(ctx.get('captcha', 'settings', 'rate_limit_window') || '60');
	let lockout = int(ctx.get('captcha', 'settings', 'rate_limit_lockout') || '300');
	
	let now = time();
	let state = load_rate_limit_state();
	
	if (!state[ip]) {
		state[ip] = { attempts: [], locked_until: 0 };
	}
	
	let ip_state = state[ip];
	
	if (ip_state.locked_until > now) {
		return { allowed: false, remaining: 0, locked_until: ip_state.locked_until };
	}
	
	let recent_attempts = [];
	for (let attempt in ip_state.attempts) {
		if (attempt > (now - window)) {
			push(recent_attempts, attempt);
		}
	}
	ip_state.attempts = recent_attempts;
	
	let remaining = max_attempts - length(ip_state.attempts);
	if (remaining <= 0) {
		ip_state.locked_until = now + lockout;
		ip_state.attempts = [];
		save_rate_limit_state(state);
		return { allowed: false, remaining: 0, locked_until: ip_state.locked_until };
	}
	
	save_rate_limit_state(state);
	return { allowed: true, remaining: remaining, locked_until: 0 };
}

function record_failed_attempt(ip) {
	let uci = require('uci');
	let ctx = uci.cursor();
	
	let rate_limit_enabled = ctx.get('captcha', 'settings', 'rate_limit_enabled');
	if (rate_limit_enabled != '1')
		return;
	
	let now = time();
	let state = load_rate_limit_state();
	
	if (!state[ip]) {
		state[ip] = { attempts: [], locked_until: 0 };
	}
	
	push(state[ip].attempts, now);
	save_rate_limit_state(state);
}

function clear_rate_limit(ip) {
	let state = load_rate_limit_state();
	if (state[ip]) {
		delete state[ip];
		save_rate_limit_state(state);
	}
}

// Check if CAPTCHA is enabled
function is_captcha_enabled() {
	let uci = require('uci');
	let ctx = uci.cursor();
	
	let enabled = ctx.get('captcha', 'settings', 'enabled');
	return enabled == '1';
}

// Get CAPTCHA provider
function get_captcha_provider() {
	let uci = require('uci');
	let ctx = uci.cursor();
	return ctx.get('captcha', 'settings', 'provider') || 'local';
}

// Generate local SVG CAPTCHA
function generate_local_captcha() {
	let uci = require('uci');
	let ctx = uci.cursor();
	let fs = require('fs');
	let rand = require('math').rand;
	
	let text_len = int(ctx.get('captcha', 'settings', 'local_length') || '4');
	let noise = int(ctx.get('captcha', 'settings', 'local_noise') || '50');
	let case_sensitive = ctx.get('captcha', 'settings', 'local_case_sensitive') == '1';
	
	// Generate random text
	let chars = case_sensitive ?
		'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789' :
		'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
	
	let text = '';
	for (let i = 0; i < text_len; i++) {
		let idx = rand() % length(chars);
		text += substr(chars, idx, 1);
	}
	
	// Generate random ID for this CAPTCHA
	let captcha_id = '';
	for (let i = 0; i < 16; i++) {
		captcha_id += sprintf('%x', rand() % 16);
	}
	
	// Store the expected answer
	let captcha_store = {};
	let store_content = fs.readfile('/tmp/captcha_store.json');
	if (store_content) {
		captcha_store = json(store_content) || {};
	}
	
	// Clean old entries (older than 5 minutes)
	let now = time();
	for (let id, data in captcha_store) {
		if (data.expires < now) {
			delete captcha_store[id];
		}
	}
	
	// Store new CAPTCHA
	captcha_store[captcha_id] = {
		text: case_sensitive ? text : uc(text),
		case_sensitive: case_sensitive,
		expires: now + 300  // 5 minutes
	};
	
	fs.writefile('/tmp/captcha_store.json', sprintf('%J', captcha_store));
	
	// Generate SVG CAPTCHA
	let width = 200;
	let height = 60;
	let svg = sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" style="display:block; margin:0 auto; border-radius:6px; box-shadow:0 1px 4px rgba(0,0,0,0.15);">', width, height, width, height);
	
	// Background with subtle gradient
	svg += '<defs><linearGradient id="captcha-bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f8f9fa"/><stop offset="100%" stop-color="#e9ecef"/></linearGradient></defs>';
	svg += sprintf('<rect width="%d" height="%d" rx="6" ry="6" fill="url(#captcha-bg)"/>', width, height);
	
	// Add noise lines
	for (let i = 0; i < noise; i++) {
		let x1 = rand() % width;
		let y1 = rand() % height;
		let x2 = rand() % width;
		let y2 = rand() % height;
		let r = rand() % 200;
		let g = rand() % 200;
		let b = rand() % 200;
		svg += sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="rgb(%d,%d,%d)" stroke-width="1" opacity="0.3"/>', x1, y1, x2, y2, r, g, b);
	}
	
	// Draw characters with distortion
	let char_width = width / (text_len + 1);
	for (let i = 0; i < text_len; i++) {
		let char = substr(text, i, 1);
		let x = (i + 0.5) * char_width + (rand() % 8) - 4;
		let y = height / 2 + 6 + (rand() % 8) - 4;
		let rotation = (rand() % 24) - 12;
		let font_size = 26 + (rand() % 8);
		let r = rand() % 80;
		let g = rand() % 80;
		let b = rand() % 80;
		
		svg += sprintf('<text x="%d" y="%d" font-family="\'Courier New\', monospace" font-size="%d" font-weight="bold" fill="rgb(%d,%d,%d)" transform="rotate(%d %d %d)">%s</text>',
			int(x), int(y), font_size, r, g, b, rotation, int(x), int(y), char);
	}
	
	// Add noise dots
	for (let i = 0; i < noise * 2; i++) {
		let cx = rand() % width;
		let cy = rand() % height;
		let r = rand() % 200;
		let g = rand() % 200;
		let b = rand() % 200;
		svg += sprintf('<circle cx="%d" cy="%d" r="1" fill="rgb(%d,%d,%d)" opacity="0.5"/>', cx, cy, r, g, b);
	}
	
	svg += '</svg>';
	
	return {
		id: captcha_id,
		svg: svg
	};
}

// Verify local CAPTCHA
function verify_local_captcha(captcha_id, answer) {
	let fs = require('fs');
	
	if (!captcha_id || !answer)
		return false;
	
	let store_content = fs.readfile('/tmp/captcha_store.json');
	if (!store_content)
		return false;
	
	let captcha_store = json(store_content);
	if (!captcha_store || !captcha_store[captcha_id])
		return false;
	
	let stored = captcha_store[captcha_id];
	let now = time();
	
	// Check expiration
	if (stored.expires < now) {
		delete captcha_store[captcha_id];
		fs.writefile('/tmp/captcha_store.json', sprintf('%J', captcha_store));
		return false;
	}
	
	// Verify answer
	let expected = stored.text;
	let user_answer = stored.case_sensitive ? answer : uc(answer);
	
	// Remove used CAPTCHA
	delete captcha_store[captcha_id];
	fs.writefile('/tmp/captcha_store.json', sprintf('%J', captcha_store));
	
	return expected == user_answer;
}

// Verify Cloudflare Turnstile
function verify_turnstile(token) {
	let uci = require('uci');
	let ctx = uci.cursor();
	let fs = require('fs');
	
	let secret = ctx.get('captcha', 'settings', 'turnstile_secret');
	if (!secret || secret == '')
		return false;
	
	// Validate token format to prevent command injection
	// Turnstile tokens are alphanumeric with hyphens, underscores and dots
	if (!token || !match(token, /^[a-zA-Z0-9._-]+$/))
		return false;
	
	// Validate secret format - should be alphanumeric with limited special chars
	if (!match(secret, /^[a-zA-Z0-9._-]+$/))
		return false;
	
	// Write POST data to temp file to avoid shell injection
	let data_file = '/tmp/captcha_verify_' + time() + '.tmp';
	let data = 'secret=' + secret + '&response=' + token;
	fs.writefile(data_file, data);
	
	// Use curl with --data-binary to read from file
	let fd = fs.popen(
		"curl -s -X POST 'https://challenges.cloudflare.com/turnstile/v0/siteverify' " +
		"-H 'Content-Type: application/x-www-form-urlencoded' " +
		"--data-binary '@" + data_file + "'",
		'r'
	);
	
	let response = fd ? fd.read('all') : null;
	if (fd) fd.close();
	
	// Clean up temp file
	fs.unlink(data_file);
	
	if (!response)
		return false;
	
	let result = json(response);
	return result?.success == true;
}

// Verify hCaptcha
function verify_hcaptcha(token) {
	let uci = require('uci');
	let ctx = uci.cursor();
	let fs = require('fs');
	
	let secret = ctx.get('captcha', 'settings', 'hcaptcha_secret');
	if (!secret || secret == '')
		return false;
	
	// Validate token format to prevent command injection
	// hCaptcha tokens are alphanumeric with hyphens, underscores and dots
	if (!token || !match(token, /^[a-zA-Z0-9._-]+$/))
		return false;
	
	// Validate secret format - should be alphanumeric with limited special chars
	if (!match(secret, /^[a-zA-Z0-9._-]+$/))
		return false;
	
	// Write POST data to temp file to avoid shell injection
	let data_file = '/tmp/captcha_verify_' + time() + '.tmp';
	let data = 'secret=' + secret + '&response=' + token;
	fs.writefile(data_file, data);
	
	// Use curl with --data-binary to read from file
	let fd = fs.popen(
		"curl -s -X POST 'https://hcaptcha.com/siteverify' " +
		"-H 'Content-Type: application/x-www-form-urlencoded' " +
		"--data-binary '@" + data_file + "'",
		'r'
	);
	
	let response = fd ? fd.read('all') : null;
	if (fd) fd.close();
	
	// Clean up temp file
	fs.unlink(data_file);
	
	if (!response)
		return false;
	
	let result = json(response);
	return result?.success == true;
}

// Get client IP from HTTP request
function get_client_ip(http) {
	let ip = null;
	
	if (http && http.getenv) {
		ip = http.getenv('REMOTE_ADDR');
		
		if (ip && (ip == '127.0.0.1' || ip == '::1')) {
			let xff = http.getenv('HTTP_X_FORWARDED_FOR');
			if (xff) {
				let parts = split(xff, ',');
				ip = trim(parts[0]);
			}
		}
	}
	
	return ip || '';
}

return {
	name: 'captcha',
	priority: 20,  // Lower priority than 2FA (runs after 2FA if both are enabled)

	check: function(http, user) {
		let client_ip = get_client_ip(http);
		
		// Check if IP is whitelisted (bypass CAPTCHA)
		if (client_ip && is_ip_whitelisted(client_ip)) {
			return { required: false, whitelisted: true };
		}
		
		// Check rate limit
		if (client_ip) {
			let rate_check = check_rate_limit(client_ip);
			if (!rate_check.allowed) {
				let remaining_seconds = rate_check.locked_until - time();
				return {
					required: true,
					blocked: true,
					message: sprintf('Too many failed attempts. Please try again in %d seconds.', remaining_seconds),
					fields: []
				};
			}
		}
		
		if (!is_captcha_enabled()) {
			return { required: false };
		}

		let provider = get_captcha_provider();
		let uci = require('uci');
		let ctx = uci.cursor();
		
		if (provider == 'turnstile') {
			let sitekey = ctx.get('captcha', 'settings', 'turnstile_sitekey');
			if (!sitekey || sitekey == '')
				return { required: false };
			
			return {
				required: true,
				fields: [
					{
						name: 'cf-turnstile-response',
						type: 'hidden',
						required: true
					}
				],
				html: sprintf(
					'<div class="cf-turnstile" data-sitekey="%s" data-callback="onTurnstileCallback"></div>' +
					'<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>' +
					'<script>function onTurnstileCallback(token){document.querySelector(\'input[name="cf-turnstile-response"]\').value=token;}</script>',
					sitekey
				),
				message: 'Please complete the CAPTCHA verification.'
			};
		}
		else if (provider == 'hcaptcha') {
			let sitekey = ctx.get('captcha', 'settings', 'hcaptcha_sitekey');
			if (!sitekey || sitekey == '')
				return { required: false };
			
			return {
				required: true,
				fields: [
					{
						name: 'h-captcha-response',
						type: 'hidden',
						required: true
					}
				],
				html: sprintf(
					'<div class="h-captcha" data-sitekey="%s" data-callback="onHcaptchaCallback"></div>' +
					'<script src="https://js.hcaptcha.com/1/api.js" async defer></script>' +
					'<script>function onHcaptchaCallback(token){document.querySelector(\'input[name="h-captcha-response"]\').value=token;}</script>',
					sitekey
				),
				message: 'Please complete the CAPTCHA verification.'
			};
		}
		else {
			// Local SVG CAPTCHA
			let captcha = generate_local_captcha();
			
			return {
				required: true,
				fields: [
					{
						name: 'luci_captcha',
						type: 'text',
						label: 'Verification Code',
						placeholder: 'Enter the code shown below',
						autocomplete: 'off',
						maxlength: 8,
						required: true
					}
				],
				html: sprintf('<input type="hidden" name="luci_captcha_id" value="%s" />', captcha.id) + captcha.svg,
				message: 'Please enter the characters shown in the image.'
			};
		}
	},

	verify: function(http, user) {
		let client_ip = get_client_ip(http);
		
		// Check if IP is whitelisted
		if (client_ip && is_ip_whitelisted(client_ip)) {
			return { success: true, whitelisted: true };
		}
		
		// Check rate limit
		if (client_ip) {
			let rate_check = check_rate_limit(client_ip);
			if (!rate_check.allowed) {
				let remaining_seconds = rate_check.locked_until - time();
				return {
					success: false,
					rate_limited: true,
					message: sprintf('Too many failed attempts. Please try again in %d seconds.', remaining_seconds)
				};
			}
		}
		
		let provider = get_captcha_provider();
		let success = false;
		
		if (provider == 'turnstile') {
			let token = http.formvalue('cf-turnstile-response');
			if (!token || token == '') {
				if (client_ip) record_failed_attempt(client_ip);
				return {
					success: false,
					message: 'Please complete the Turnstile verification.'
				};
			}
			success = verify_turnstile(token);
		}
		else if (provider == 'hcaptcha') {
			let token = http.formvalue('h-captcha-response');
			if (!token || token == '') {
				if (client_ip) record_failed_attempt(client_ip);
				return {
					success: false,
					message: 'Please complete the hCaptcha verification.'
				};
			}
			success = verify_hcaptcha(token);
		}
		else {
			// Local CAPTCHA
			let captcha_id = http.formvalue('luci_captcha_id');
			let answer = http.formvalue('luci_captcha');
			
			if (!captcha_id || !answer || answer == '') {
				if (client_ip) record_failed_attempt(client_ip);
				return {
					success: false,
					message: 'Please enter the CAPTCHA code.'
				};
			}
			
			success = verify_local_captcha(captcha_id, answer);
		}
		
		if (!success) {
			if (client_ip) record_failed_attempt(client_ip);
			return {
				success: false,
				message: 'CAPTCHA verification failed. Please try again.'
			};
		}

		// Clear rate limit on successful verification
		if (client_ip) clear_rate_limit(client_ip);
		
		return { success: true };
	}
};
