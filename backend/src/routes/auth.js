const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { db } = require('../db');
const { generateToken, authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Sign up with email
router.post('/signup', async (req, res) => {
  try {
    const { email, name, password } = req.body;

    if (!email || !name || !password) {
      return res.status(400).json({ error: 'Email, name, and password are required' });
    }

    // Check if user exists
    const existingUser = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }

    const id = uuidv4();
    const passwordHash = await bcrypt.hash(password, 10);

    db.prepare(`
      INSERT INTO users (id, email, name, password_hash, provider)
      VALUES (?, ?, ?, ?, 'email')
    `).run(id, email, name, passwordHash);

    const user = { id, email, name };
    const token = generateToken(user);

    res.status(201).json({ user, token });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Sign in with email
router.post('/signin', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const user = db.prepare('SELECT * FROM users WHERE email = ? AND provider = ?').get(email, 'email');
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = generateToken(user);
    res.json({
      user: { id: user.id, email: user.email, name: user.name },
      token
    });
  } catch (error) {
    console.error('Signin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Sign in with Apple
router.post('/apple', (req, res) => {
  try {
    const { userId, email, name } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'Apple user ID required' });
    }

    let user = db.prepare('SELECT * FROM users WHERE provider = ? AND provider_id = ?').get('apple', userId);

    if (!user) {
      const id = uuidv4();
      const userEmail = email || `${userId.substring(0, 8)}@apple.com`;
      const userName = name || 'Apple User';

      db.prepare(`
        INSERT INTO users (id, email, name, provider, provider_id)
        VALUES (?, ?, ?, 'apple', ?)
      `).run(id, userEmail, userName, userId);

      user = { id, email: userEmail, name: userName };
    } else {
      user = { id: user.id, email: user.email, name: user.name };
    }

    const token = generateToken(user);
    res.json({ user, token });
  } catch (error) {
    console.error('Apple signin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Sign in with Google
router.post('/google', (req, res) => {
  try {
    const { userId, email, name } = req.body;

    if (!userId || !email) {
      return res.status(400).json({ error: 'Google user ID and email required' });
    }

    let user = db.prepare('SELECT * FROM users WHERE provider = ? AND provider_id = ?').get('google', userId);

    if (!user) {
      const id = uuidv4();

      db.prepare(`
        INSERT INTO users (id, email, name, provider, provider_id)
        VALUES (?, ?, ?, 'google', ?)
      `).run(id, email, name || 'Google User', userId);

      user = { id, email, name: name || 'Google User' };
    } else {
      user = { id: user.id, email: user.email, name: user.name };
    }

    const token = generateToken(user);
    res.json({ user, token });
  } catch (error) {
    console.error('Google signin error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get current user
router.get('/me', authenticateToken, (req, res) => {
  try {
    const user = db.prepare('SELECT id, email, name, provider, created_at FROM users WHERE id = ?').get(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ user });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
