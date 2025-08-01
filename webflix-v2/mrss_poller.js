const axios = require('axios');
const xml2js = require('xml2js');
const mysql2 = require('mysql2/promise');
const AWS = require('aws-sdk');

exports.handler = async (event) => {
  const { feed_id } = event;

  if (!feed_id) {
    console.error('No feed_id provided');
    return { statusCode: 400, body: 'Missing feed_id' };
  }

  try {
    // Create DB connection
    const connection = await mysql2.createConnection({
      host: process.env.RDS_HOST,
      port: process.env.RDS_PORT,
      user: 'admin',
      password: process.env.RDS_PASSWORD,
      database: 'video_platform'
    });

    // Get feed details
    const [feeds] = await connection.execute('SELECT * FROM feeds WHERE id = ?', [feed_id]);
    if (feeds.length === 0) {
      await connection.end();
      return { statusCode: 404, body: 'Feed not found' };
    }
    const feed = feeds[0];

    // Fetch and parse MRSS feed
    const response = await axios.get(feed.url);
    console.log("response is ", response);
    const parsed = await xml2js.parseStringPromise(response.data);
    console.log("parsed data is ", parsed);
    const items = parsed.rss.channel[0].item || [];
    console.log("items are ", items);

    for (const item of items) {
      console.log("entered if", item);
      const mediaGroup = item['media:group'] && item['media:group'][0];
      if (!mediaGroup || !mediaGroup['media:content']) continue;
      console.log("media group is ", mediaGroup);
      const mediaContents = mediaGroup['media:content'];
      console.log("media content is ", mediaContents);

      // Select highest quality MP4, or any video/mp4
      const selected = mediaContents.find(m => m.$.type === 'video/mp4' && m.$.width === '1080') ||
                      mediaContents.find(m => m.$.type === 'video/mp4');
      console.log("selected is ", selected);

      if (!selected) continue;

      const s3_url = selected.$.url;
      console.log("s3 url is ", s3_url);

      // Check if video already exists
      const [existing] = await connection.execute('SELECT id FROM videos WHERE s3_url = ?', [s3_url]);
      if (existing.length > 0) continue;

      console.log("inserting videos to video tabel", item);

      // Insert video metadata
      const [result] = await connection.execute(
        'INSERT INTO videos (title, description, source_type, source_id, s3_url) VALUES (?, ?, ?, ?, ?)',
        [
          item.title && item.title[0] || 'Untitled',
          item.description && item.description[0] || '',
          'mrss',
          feed.id,
          s3_url
        ]
      );

      // Trigger Mux submission
      const lambda = new AWS.Lambda();
      console.log(`Invoking mux_submitter for video_id=${result.insertId}, s3_url=${s3_url}`);

      await lambda.invoke({
        FunctionName: 'video-platform-mux-submitter',
        InvocationType: 'Event',
        Payload: JSON.stringify({
          video_id: result.insertId,
          s3_url
        })
      }).promise();
    }


    // Update last_polled
    await connection.execute('UPDATE feeds SET last_polled = NOW() WHERE id = ?', [feed.id]);

    await connection.end();
    return { statusCode: 200, body: `Feed ${feed_id} processed` };
  } catch (error) {
    console.error(`Error processing feed ${feed_id}:`, error);
    return { statusCode: 500, body: `Error processing feed ${feed_id}` };
  }
};