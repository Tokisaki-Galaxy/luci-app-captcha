// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2024 LuCI CAPTCHA Plugin Contributors
//
// RPC backend for CAPTCHA authentication configuration

'use strict';

let uci = require('uci');
let fs = require('fs');

const RATE_LIMIT_FILE = '/tmp/captcha_rate_limit.json';
const CAPTCHA_STORE_FILE = '/tmp/captcha_store.json';
const SECRET_MASK = '***configured***';

function load_rate_limit_state() {
	let content = fs.readfile(RATE_LIMIT_FILE);
	if (!content)
		return {};
	
	let state = json(content);
	return state || {};
}

function save_rate_limit_state(state) {
	fs.writefile(RATE_LIMIT_FILE, sprintf('%J', state));
}

function generate_captcha_internal(length, noise, case_sensitive) {
	// Generate random text
	let chars = case_sensitive ?
		'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789' :
		'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
	
	let text = '';
	for (let i = 0; i < length; i++) {
		let idx = rand() % strlen(chars);
		text += substr(chars, idx, 1);
	}
	
	// Generate random ID
	let captcha_id = '';
	for (let i = 0; i < 16; i++) {
		captcha_id += sprintf('%x', rand() % 16);
	}
	
	// Store expected answer
	let captcha_store = {};
	let store_content = fs.readfile(CAPTCHA_STORE_FILE);
	if (store_content) {
		captcha_store = json(store_content) || {};
	}
	
	// Clean old entries
	let now = time();
	for (let id, data in captcha_store) {
		if (data.expires < now) {
			delete captcha_store[id];
		}
	}
	
	captcha_store[captcha_id] = {
		text: case_sensitive ? text : uc(text),
		case_sensitive: case_sensitive,
		expires: now + 300
	};
	
	fs.writefile(CAPTCHA_STORE_FILE, sprintf('%J', captcha_store));
	
	// Generate SVG
	let width = 150;
	let height = 50;
	let svg = sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">', width, height, width, height);
	
	svg += sprintf('<rect width="%d" height="%d" fill="#f0f0f0"/>', width, height);
	
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
	
	let char_width = width / (length + 1);
	for (let i = 0; i < length; i++) {
		let char = substr(text, i, 1);
		let x = (i + 0.5) * char_width + (rand() % 10) - 5;
		let y = height / 2 + (rand() % 10) - 5;
		let rotation = (rand() % 30) - 15;
		let font_size = 20 + (rand() % 10);
		let r = rand() % 100;
		let g = rand() % 100;
		let b = rand() % 100;
		
		svg += sprintf('<text x="%d" y="%d" font-family="monospace" font-size="%d" fill="rgb(%d,%d,%d)" transform="rotate(%d %d %d)">%s</text>',
			int(x), int(y), font_size, r, g, b, rotation, int(x), int(y), char);
	}
	
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

const methods = {
	getConfig: {
		call: function() {
			let ctx = uci.cursor();
			ctx.load('captcha');
			
			let settings = ctx.get_all('captcha', 'settings') || {};
			
			return {
				enabled: settings.enabled || '0',
				provider: settings.provider || 'local',
				local_length: settings.local_length || '4',
				local_noise: settings.local_noise || '50',
				local_case_sensitive: settings.local_case_sensitive || '0',
				turnstile_sitekey: settings.turnstile_sitekey || '',
				turnstile_secret: settings.turnstile_secret ? SECRET_MASK : '',
				hcaptcha_sitekey: settings.hcaptcha_sitekey || '',
				hcaptcha_secret: settings.hcaptcha_secret ? SECRET_MASK : '',
				ip_whitelist_enabled: settings.ip_whitelist_enabled || '0',
				ip_whitelist: settings.ip_whitelist || [],
				rate_limit_enabled: settings.rate_limit_enabled || '0',
				rate_limit_max_attempts: settings.rate_limit_max_attempts || '5',
				rate_limit_window: settings.rate_limit_window || '60',
				rate_limit_lockout: settings.rate_limit_lockout || '300'
			};
		}
	},

	setConfig: {
		args: {
			enabled: 'enabled',
			provider: 'provider',
			local_length: 'local_length',
			local_noise: 'local_noise',
			local_case_sensitive: 'local_case_sensitive',
			turnstile_sitekey: 'turnstile_sitekey',
			turnstile_secret: 'turnstile_secret',
			hcaptcha_sitekey: 'hcaptcha_sitekey',
			hcaptcha_secret: 'hcaptcha_secret',
			ip_whitelist_enabled: 'ip_whitelist_enabled',
			ip_whitelist: 'ip_whitelist',
			rate_limit_enabled: 'rate_limit_enabled',
			rate_limit_max_attempts: 'rate_limit_max_attempts',
			rate_limit_window: 'rate_limit_window',
			rate_limit_lockout: 'rate_limit_lockout'
		},
		call: function(req) {
			let ctx = uci.cursor();
			ctx.load('captcha');
			
			if (req.args.enabled !== undefined)
				ctx.set('captcha', 'settings', 'enabled', req.args.enabled);
			if (req.args.provider !== undefined)
				ctx.set('captcha', 'settings', 'provider', req.args.provider);
			if (req.args.local_length !== undefined)
				ctx.set('captcha', 'settings', 'local_length', req.args.local_length);
			if (req.args.local_noise !== undefined)
				ctx.set('captcha', 'settings', 'local_noise', req.args.local_noise);
			if (req.args.local_case_sensitive !== undefined)
				ctx.set('captcha', 'settings', 'local_case_sensitive', req.args.local_case_sensitive);
			if (req.args.turnstile_sitekey !== undefined)
				ctx.set('captcha', 'settings', 'turnstile_sitekey', req.args.turnstile_sitekey);
			if (req.args.turnstile_secret !== undefined && req.args.turnstile_secret != SECRET_MASK)
				ctx.set('captcha', 'settings', 'turnstile_secret', req.args.turnstile_secret);
			if (req.args.hcaptcha_sitekey !== undefined)
				ctx.set('captcha', 'settings', 'hcaptcha_sitekey', req.args.hcaptcha_sitekey);
			if (req.args.hcaptcha_secret !== undefined && req.args.hcaptcha_secret != SECRET_MASK)
				ctx.set('captcha', 'settings', 'hcaptcha_secret', req.args.hcaptcha_secret);
			if (req.args.ip_whitelist_enabled !== undefined)
				ctx.set('captcha', 'settings', 'ip_whitelist_enabled', req.args.ip_whitelist_enabled);
			if (req.args.ip_whitelist !== undefined)
				ctx.set('captcha', 'settings', 'ip_whitelist', req.args.ip_whitelist);
			if (req.args.rate_limit_enabled !== undefined)
				ctx.set('captcha', 'settings', 'rate_limit_enabled', req.args.rate_limit_enabled);
			if (req.args.rate_limit_max_attempts !== undefined)
				ctx.set('captcha', 'settings', 'rate_limit_max_attempts', req.args.rate_limit_max_attempts);
			if (req.args.rate_limit_window !== undefined)
				ctx.set('captcha', 'settings', 'rate_limit_window', req.args.rate_limit_window);
			if (req.args.rate_limit_lockout !== undefined)
				ctx.set('captcha', 'settings', 'rate_limit_lockout', req.args.rate_limit_lockout);
			
			ctx.commit('captcha');
			
			return { success: true };
		}
	},

	isEnabled: {
		call: function() {
			let ctx = uci.cursor();
			ctx.load('captcha');
			
			let enabled = ctx.get('captcha', 'settings', 'enabled');
			let provider = ctx.get('captcha', 'settings', 'provider') || 'local';
			
			return {
				enabled: enabled == '1',
				provider: provider
			};
		}
	},

	generateCaptcha: {
		call: function() {
			let ctx = uci.cursor();
			ctx.load('captcha');
			
			let length = int(ctx.get('captcha', 'settings', 'local_length') || '4');
			let noise = int(ctx.get('captcha', 'settings', 'local_noise') || '50');
			let case_sensitive = ctx.get('captcha', 'settings', 'local_case_sensitive') == '1';
			
			return generate_captcha_internal(length, noise, case_sensitive);
		}
	},

	verifyCaptcha: {
		args: { captcha_id: 'captcha_id', answer: 'answer' },
		call: function(req) {
			let captcha_id = req.args.captcha_id;
			let answer = req.args.answer;
			
			if (!captcha_id || !answer)
				return { success: false, message: 'Missing captcha_id or answer' };
			
			let store_content = fs.readfile(CAPTCHA_STORE_FILE);
			if (!store_content)
				return { success: false, message: 'CAPTCHA not found' };
			
			let captcha_store = json(store_content);
			if (!captcha_store || !captcha_store[captcha_id])
				return { success: false, message: 'CAPTCHA not found or expired' };
			
			let stored = captcha_store[captcha_id];
			let now = time();
			
			if (stored.expires < now) {
				delete captcha_store[captcha_id];
				fs.writefile(CAPTCHA_STORE_FILE, sprintf('%J', captcha_store));
				return { success: false, message: 'CAPTCHA expired' };
			}
			
			let expected = stored.text;
			let user_answer = stored.case_sensitive ? answer : uc(answer);
			
			delete captcha_store[captcha_id];
			fs.writefile(CAPTCHA_STORE_FILE, sprintf('%J', captcha_store));
			
			if (expected == user_answer)
				return { success: true };
			else
				return { success: false, message: 'Incorrect CAPTCHA' };
		}
	},

	checkRateLimit: {
		args: { ip: 'ip' },
		call: function(req) {
			let ip = req.args.ip;
			if (!ip)
				return { allowed: true };
			
			let ctx = uci.cursor();
			ctx.load('captcha');
			
			let rate_limit_enabled = ctx.get('captcha', 'settings', 'rate_limit_enabled');
			if (rate_limit_enabled != '1')
				return { allowed: true, remaining: -1, locked_until: 0 };
			
			let max_attempts = int(ctx.get('captcha', 'settings', 'rate_limit_max_attempts') || '5');
			let window = int(ctx.get('captcha', 'settings', 'rate_limit_window') || '60');
			let lockout = int(ctx.get('captcha', 'settings', 'rate_limit_lockout') || '300');
			
			let now = time();
			let state = load_rate_limit_state();
			
			if (!state[ip]) {
				return { allowed: true, remaining: max_attempts, locked_until: 0 };
			}
			
			let ip_state = state[ip];
			
			if (ip_state.locked_until > now) {
				return { allowed: false, remaining: 0, locked_until: ip_state.locked_until };
			}
			
			let recent_attempts = filter(ip_state.attempts, a => a > (now - window));
			let remaining = max_attempts - length(recent_attempts);
			
			return { allowed: remaining > 0, remaining: max(0, remaining), locked_until: 0 };
		}
	},

	getRateLimitStatus: {
		call: function() {
			let state = load_rate_limit_state();
			let now = time();
			let entries = [];
			
			for (let ip, data in state) {
				push(entries, {
					ip: ip,
					attempts: length(data.attempts),
					locked: data.locked_until > now,
					locked_until: data.locked_until
				});
			}
			
			return { entries: entries };
		}
	},

	clearRateLimit: {
		args: { ip: 'ip' },
		call: function(req) {
			let ip = req.args.ip;
			if (!ip)
				return { success: false, message: 'IP required' };
			
			let state = load_rate_limit_state();
			if (state[ip]) {
				delete state[ip];
				save_rate_limit_state(state);
			}
			
			return { success: true };
		}
	},

	clearAllRateLimits: {
		call: function() {
			save_rate_limit_state({});
			return { success: true };
		}
	}
};

return { 'captcha': methods };
