const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get all OTP accounts for user
router.get('/', (req, res) => {
  try {
    const accounts = db.prepare(`
      SELECT id, issuer, account_name, secret, algorithm, digits, period, created_at, updated_at
      FROM otp_accounts
      WHERE user_id = ?
      ORDER BY created_at DESC
    `).all(req.user.id);

    res.json({ accounts });
  } catch (error) {
    console.error('Get OTP accounts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add new OTP account
router.post('/', (req, res) => {
  try {
    const { issuer, accountName, secret, algorithm, digits, period } = req.body;

    if (!accountName || !secret) {
      return res.status(400).json({ error: 'Account name and secret are required' });
    }

    const id = uuidv4();

    db.prepare(`
      INSERT INTO otp_accounts (id, user_id, issuer, account_name, secret, algorithm, digits, period)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      id,
      req.user.id,
      issuer || '',
      accountName,
      secret,
      algorithm || 'SHA1',
      digits || 6,
      period || 30
    );

    const account = db.prepare('SELECT * FROM otp_accounts WHERE id = ?').get(id);
    res.status(201).json({ account });
  } catch (error) {
    console.error('Add OTP account error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Add multiple OTP accounts (bulk sync)
router.post('/sync', (req, res) => {
  try {
    const { accounts } = req.body;

    if (!Array.isArray(accounts)) {
      return res.status(400).json({ error: 'Accounts array is required' });
    }

    const insertStmt = db.prepare(`
      INSERT OR REPLACE INTO otp_accounts (id, user_id, issuer, account_name, secret, algorithm, digits, period, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    `);

    const insertMany = db.transaction((accounts) => {
      for (const account of accounts) {
        insertStmt.run(
          account.id || uuidv4(),
          req.user.id,
          account.issuer || '',
          account.accountName,
          account.secret,
          account.algorithm || 'SHA1',
          account.digits || 6,
          account.period || 30
        );
      }
    });

    insertMany(accounts);

    const updatedAccounts = db.prepare(`
      SELECT id, issuer, account_name, secret, algorithm, digits, period, created_at, updated_at
      FROM otp_accounts
      WHERE user_id = ?
      ORDER BY created_at DESC
    `).all(req.user.id);

    res.json({ accounts: updatedAccounts });
  } catch (error) {
    console.error('Sync OTP accounts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update OTP account
router.put('/:id', (req, res) => {
  try {
    const { id } = req.params;
    const { issuer, accountName, secret } = req.body;

    const existing = db.prepare('SELECT * FROM otp_accounts WHERE id = ? AND user_id = ?').get(id, req.user.id);
    if (!existing) {
      return res.status(404).json({ error: 'OTP account not found' });
    }

    db.prepare(`
      UPDATE otp_accounts
      SET issuer = ?, account_name = ?, secret = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND user_id = ?
    `).run(
      issuer ?? existing.issuer,
      accountName ?? existing.account_name,
      secret ?? existing.secret,
      id,
      req.user.id
    );

    const account = db.prepare('SELECT * FROM otp_accounts WHERE id = ?').get(id);
    res.json({ account });
  } catch (error) {
    console.error('Update OTP account error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete OTP account
router.delete('/:id', (req, res) => {
  try {
    const { id } = req.params;

    const result = db.prepare('DELETE FROM otp_accounts WHERE id = ? AND user_id = ?').run(id, req.user.id);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'OTP account not found' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete OTP account error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete all OTP accounts for user
router.delete('/', (req, res) => {
  try {
    db.prepare('DELETE FROM otp_accounts WHERE user_id = ?').run(req.user.id);
    res.json({ success: true });
  } catch (error) {
    console.error('Delete all OTP accounts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Parse OTP URI (otpauth://totp/...)
router.post('/parse-uri', (req, res) => {
  try {
    const { uri } = req.body;

    if (!uri || !uri.startsWith('otpauth://')) {
      return res.status(400).json({ error: 'Invalid OTP URI' });
    }

    const url = new URL(uri);
    const type = url.hostname; // totp or hotp
    const path = decodeURIComponent(url.pathname.slice(1)); // Remove leading /
    const secret = url.searchParams.get('secret');
    const issuer = url.searchParams.get('issuer') || '';
    const algorithm = url.searchParams.get('algorithm') || 'SHA1';
    const digits = parseInt(url.searchParams.get('digits') || '6', 10);
    const period = parseInt(url.searchParams.get('period') || '30', 10);

    // Parse account name from path (format: "Issuer:account" or just "account")
    let accountName = path;
    let parsedIssuer = issuer;
    if (path.includes(':')) {
      const parts = path.split(':');
      if (!parsedIssuer) parsedIssuer = parts[0];
      accountName = parts.slice(1).join(':');
    }

    if (!secret) {
      return res.status(400).json({ error: 'Secret not found in URI' });
    }

    res.json({
      type,
      issuer: parsedIssuer,
      accountName,
      secret,
      algorithm,
      digits,
      period
    });
  } catch (error) {
    console.error('Parse URI error:', error);
    res.status(400).json({ error: 'Invalid OTP URI format' });
  }
});

module.exports = router;
