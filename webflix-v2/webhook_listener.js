const mysql2 = require('mysql2/promise');

exports.handler = async (event) => {
  const payload = JSON.parse(event.body);
  const { type, data } = payload;
  console.log('Incoming event.body:', event.body);


  if (!['video.asset.ready', 'video.asset.errored'].includes(type)) {
    return { statusCode: 200, body: 'Ignored event' };
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

    const passthrough = JSON.parse(data.passthrough);
    const video_id = passthrough.video_id;

    // Update video status
    await connection.execute(
      'UPDATE videos SET mux_status = ?, mux_playback_id = ? WHERE id = ?',
      [
        type === 'video.asset.ready' ? 'ready' : 'errored',
        type === 'video.asset.ready' ? data.playback_ids[0].id : null,
        video_id
      ]
    );

    await connection.end();
    return { statusCode: 200, body: 'Webhook processed' };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: 'Error processing webhook' };
  }
};