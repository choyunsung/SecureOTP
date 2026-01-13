const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get all devices for user
router.get('/', (req, res) => {
  try {
    const devices = db.prepare(`
      SELECT id, device_name, device_model, os_version, app_version,
             last_sync_at, created_at, updated_at
      FROM devices
      WHERE user_id = ?
      ORDER BY last_sync_at DESC
    `).all(req.user.id);

    res.json({ devices });
  } catch (error) {
    console.error('Get devices error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Register or update device
router.post('/register', (req, res) => {
  try {
    const { deviceId, deviceName, deviceModel, osVersion, appVersion, pushToken } = req.body;

    if (!deviceId) {
      return res.status(400).json({ error: 'Device ID is required' });
    }

    // Check if device already exists
    const existing = db.prepare(
      'SELECT id FROM devices WHERE id = ? AND user_id = ?'
    ).get(deviceId, req.user.id);

    if (existing) {
      // Update existing device
      db.prepare(`
        UPDATE devices
        SET device_name = ?, device_model = ?, os_version = ?, app_version = ?,
            push_token = ?, last_sync_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE id = ? AND user_id = ?
      `).run(
        deviceName || null,
        deviceModel || null,
        osVersion || null,
        appVersion || null,
        pushToken || null,
        deviceId,
        req.user.id
      );

      const device = db.prepare('SELECT * FROM devices WHERE id = ?').get(deviceId);
      return res.json({ device, updated: true });
    }

    // Create new device
    db.prepare(`
      INSERT INTO devices (
        id, user_id, device_name, device_model, os_version, app_version,
        push_token, last_sync_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    `).run(
      deviceId,
      req.user.id,
      deviceName || null,
      deviceModel || null,
      osVersion || null,
      appVersion || null,
      pushToken || null
    );

    const device = db.prepare('SELECT * FROM devices WHERE id = ?').get(deviceId);
    res.status(201).json({ device, created: true });
  } catch (error) {
    console.error('Register device error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update device sync timestamp
router.post('/:id/sync', (req, res) => {
  try {
    const { id } = req.params;

    const result = db.prepare(`
      UPDATE devices
      SET last_sync_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND user_id = ?
    `).run(id, req.user.id);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }

    const device = db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
    res.json({ device });
  } catch (error) {
    console.error('Sync device error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update push token
router.put('/:id/push-token', (req, res) => {
  try {
    const { id } = req.params;
    const { pushToken } = req.body;

    const result = db.prepare(`
      UPDATE devices
      SET push_token = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND user_id = ?
    `).run(pushToken || null, id, req.user.id);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }

    const device = db.prepare('SELECT * FROM devices WHERE id = ?').get(id);
    res.json({ device });
  } catch (error) {
    console.error('Update push token error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Remove device
router.delete('/:id', (req, res) => {
  try {
    const { id } = req.params;

    const result = db.prepare(
      'DELETE FROM devices WHERE id = ? AND user_id = ?'
    ).run(id, req.user.id);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Remove device error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Remove all devices except current
router.post('/logout-all', (req, res) => {
  try {
    const { exceptDeviceId } = req.body;

    let result;
    if (exceptDeviceId) {
      result = db.prepare(
        'DELETE FROM devices WHERE user_id = ? AND id != ?'
      ).run(req.user.id, exceptDeviceId);
    } else {
      result = db.prepare(
        'DELETE FROM devices WHERE user_id = ?'
      ).run(req.user.id);
    }

    res.json({ success: true, removedCount: result.changes });
  } catch (error) {
    console.error('Logout all devices error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
