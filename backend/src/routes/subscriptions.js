const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get user's subscription status
router.get('/', (req, res) => {
  try {
    const subscription = db.prepare(`
      SELECT id, product_id, transaction_id, original_transaction_id,
             purchase_date, expires_date, is_active, created_at, updated_at
      FROM subscriptions
      WHERE user_id = ? AND is_active = 1
      ORDER BY expires_date DESC
      LIMIT 1
    `).get(req.user.id);

    res.json({
      subscription: subscription || null,
      isSubscribed: !!subscription && new Date(subscription.expires_date) > new Date()
    });
  } catch (error) {
    console.error('Get subscription error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get subscription history
router.get('/history', (req, res) => {
  try {
    const subscriptions = db.prepare(`
      SELECT id, product_id, transaction_id, original_transaction_id,
             purchase_date, expires_date, is_active, created_at, updated_at
      FROM subscriptions
      WHERE user_id = ?
      ORDER BY created_at DESC
    `).all(req.user.id);

    res.json({ subscriptions });
  } catch (error) {
    console.error('Get subscription history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify and save subscription (App Store receipt validation)
router.post('/verify', (req, res) => {
  try {
    const {
      productId,
      transactionId,
      originalTransactionId,
      purchaseDate,
      expiresDate,
      receiptData
    } = req.body;

    if (!productId || !transactionId) {
      return res.status(400).json({ error: 'Product ID and transaction ID are required' });
    }

    // Check if transaction already exists
    const existing = db.prepare(
      'SELECT id FROM subscriptions WHERE transaction_id = ?'
    ).get(transactionId);

    if (existing) {
      // Update existing subscription
      db.prepare(`
        UPDATE subscriptions
        SET expires_date = ?, is_active = 1, updated_at = CURRENT_TIMESTAMP
        WHERE transaction_id = ?
      `).run(expiresDate, transactionId);

      const subscription = db.prepare('SELECT * FROM subscriptions WHERE id = ?').get(existing.id);
      return res.json({ subscription, updated: true });
    }

    // Deactivate previous subscriptions for this user
    db.prepare(`
      UPDATE subscriptions
      SET is_active = 0, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = ? AND is_active = 1
    `).run(req.user.id);

    // Create new subscription
    const id = uuidv4();
    db.prepare(`
      INSERT INTO subscriptions (
        id, user_id, product_id, transaction_id, original_transaction_id,
        purchase_date, expires_date, is_active, receipt_data
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
    `).run(
      id,
      req.user.id,
      productId,
      transactionId,
      originalTransactionId || transactionId,
      purchaseDate || new Date().toISOString(),
      expiresDate,
      receiptData || null
    );

    const subscription = db.prepare('SELECT * FROM subscriptions WHERE id = ?').get(id);
    res.status(201).json({ subscription, created: true });
  } catch (error) {
    console.error('Verify subscription error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Restore purchases (sync from App Store)
router.post('/restore', (req, res) => {
  try {
    const { transactions } = req.body;

    if (!Array.isArray(transactions)) {
      return res.status(400).json({ error: 'Transactions array is required' });
    }

    const results = [];

    for (const txn of transactions) {
      const existing = db.prepare(
        'SELECT id FROM subscriptions WHERE transaction_id = ?'
      ).get(txn.transactionId);

      if (existing) {
        // Update existing
        db.prepare(`
          UPDATE subscriptions
          SET expires_date = ?, is_active = ?, updated_at = CURRENT_TIMESTAMP
          WHERE transaction_id = ?
        `).run(
          txn.expiresDate,
          new Date(txn.expiresDate) > new Date() ? 1 : 0,
          txn.transactionId
        );
        results.push({ transactionId: txn.transactionId, action: 'updated' });
      } else {
        // Create new
        const id = uuidv4();
        db.prepare(`
          INSERT INTO subscriptions (
            id, user_id, product_id, transaction_id, original_transaction_id,
            purchase_date, expires_date, is_active
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
          id,
          req.user.id,
          txn.productId,
          txn.transactionId,
          txn.originalTransactionId || txn.transactionId,
          txn.purchaseDate,
          txn.expiresDate,
          new Date(txn.expiresDate) > new Date() ? 1 : 0
        );
        results.push({ transactionId: txn.transactionId, action: 'created' });
      }
    }

    // Get current active subscription
    const subscription = db.prepare(`
      SELECT * FROM subscriptions
      WHERE user_id = ? AND is_active = 1
      ORDER BY expires_date DESC
      LIMIT 1
    `).get(req.user.id);

    res.json({
      results,
      subscription,
      isSubscribed: !!subscription && new Date(subscription.expires_date) > new Date()
    });
  } catch (error) {
    console.error('Restore purchases error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Cancel subscription (mark as inactive)
router.post('/cancel', (req, res) => {
  try {
    const result = db.prepare(`
      UPDATE subscriptions
      SET is_active = 0, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = ? AND is_active = 1
    `).run(req.user.id);

    res.json({ success: true, cancelled: result.changes > 0 });
  } catch (error) {
    console.error('Cancel subscription error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
