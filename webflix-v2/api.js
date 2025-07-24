const express = require('express');
const mysql2 = require('mysql2/promise');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const eventBridge = new AWS.EventBridge();
const app = express();

app.use(express.json());

// Create DB pool
const pool = mysql2.createPool({
  host: process.env.RDS_HOST,
  user: 'admin',
  password: process.env.RDS_PASSWORD,
  database: 'video_platform'
});

// Helper function to manage EventBridge rule
async function manageEventBridgeRule(feedId, intervalMinutes, enable = true) {
  const ruleName = `mrss-feed-${feedId}`;
  try {
    // Create or update rule
    await eventBridge.putRule({
      Name: ruleName,
      ScheduleExpression: `rate(${intervalMinutes} minutes)`,
      State: enable ? 'ENABLED' : 'DISABLED'
    }).promise();

    // Add target
    await eventBridge.putTargets({
      Rule: ruleName,
      Targets: [{
        Id: 'mrssPoller',
        Arn: process.env.MRSS_POLLER_ARN,
        Input: JSON.stringify({ feed_id: feedId })
      }]
    }).promise();

    return ruleName;
  } catch (error) {
    console.error(`Error managing EventBridge rule for feed ${feedId}:`, error);
    throw error;
  }
}

// Add MRSS feed
app.post('/feeds', async (req, res) => {
  const { name, url, interval_minutes } = req.body;
  if (!name || !url || !interval_minutes) {
    return res.status(400).send('Missing required fields');
  }

  try {
    const [result] = await pool.execute(
      'INSERT INTO feeds (name, url, interval_minutes) VALUES (?, ?, ?)',
      [name, url, interval_minutes]
    );

    // Create EventBridge rule
    const ruleName = await manageEventBridgeRule(result.insertId, interval_minutes);

    // Update feed with rule name
    await pool.execute('UPDATE feeds SET eventbridge_rule = ? WHERE id = ?', [ruleName, result.insertId]);

    res.status(201).json({ id: result.insertId });
  } catch (error) {
    res.status(500).send('Error creating feed');
  }
});

// Update MRSS feed
app.put('/feeds/:id', async (req, res) => {
  const { id } = req.params;
  const { name, url, interval_minutes } = req.body;

  try {
    const [existing] = await pool.execute('SELECT * FROM feeds WHERE id = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).send('Feed not found');
    }

    // Update feed in DB
    await pool.execute(
      'UPDATE feeds SET name = ?, url = ?, interval_minutes = ? WHERE id = ?',
      [name || existing[0].name, url || existing[0].url, interval_minutes || existing[0].interval_minutes, id]
    );

    // Update EventBridge rule
    const newInterval = interval_minutes || existing[0].interval_minutes;
    await manageEventBridgeRule(id, newInterval);

    res.status(200).send('Feed updated');
  } catch (error) {
    res.status(500).send('Error updating feed');
  }
});

// Delete MRSS feed
app.delete('/feeds/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const [feeds] = await pool.execute('SELECT eventbridge_rule FROM feeds WHERE id = ?', [id]);
    if (feeds.length === 0) {
      return res.status(404).send('Feed not found');
    }

    // Delete EventBridge rule
    await eventBridge.deleteRule({ Name: feeds[0].eventbridge_rule }).promise();
    await eventBridge.removeTargets({ Rule: feeds[0].eventbridge_rule, Ids: ['mrssPoller'] }).promise();

    // Delete feed from DB
    await pool.execute('DELETE FROM feeds WHERE id = ?', [id]);

    res.status(200).send('Feed deleted');
  } catch (error) {
    res.status(500).send('Error deleting feed');
  }
});

// Get pre-signed upload URL
app.get('/presign-upload', async (req, res) => {
  const key = `uploads/${Date.now()}-${Math.random().toString(36).substring(2)}`;
  try {
    const url = await s3.getSignedUrlPromise('putObject', {
      Bucket: process.env.UPLOADS_BUCKET,
      Key: key,
      Expires: 3600
    });
    res.json({ url, key });
  } catch (error) {
    res.status(500).send('Error generating pre-signed URL');
  }
});

// Query videos
app.get('/videos', async (req, res) => {
  try {
    const [videos] = await pool.execute('SELECT * FROM videos');
    res.json(videos);
  } catch (error) {
    res.status(500).send('Error querying videos');
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server running on port ${port}`));