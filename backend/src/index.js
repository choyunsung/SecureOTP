require('dotenv').config();
const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const otpRoutes = require('./routes/otp');
const subscriptionRoutes = require('./routes/subscriptions');
const deviceRoutes = require('./routes/devices');
const { initDatabase } = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize database
initDatabase();

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/otp', otpRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/devices', deviceRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`SecureOTP Backend running on port ${PORT}`);
});
