const Mux = require('@mux/mux-node');
const mysql2 = require('mysql2/promise');

const { Video } = new Mux(process.env.MUX_TOKEN, process.env.MUX_SECRET);

exports.handler = async (event) => {
  const { video_id, s3_url } = event;

  try {
    // Create DB connection
    const connection = await mysql2.createConnection({
      host: process.env.RDS_HOST,
      user: 'admin',
      password: process.env.RDS_PASSWORD,
      database: 'video_platform'
    });

    // Submit to Mux
    const asset = await Video.Assets.create({
      input: s3_url,
      playback_policy: ['public'],
      passthrough: JSON.stringify({ video_id })
    });

    // Update video with Mux asset ID
    await connection.execute(
      'UPDATE videos SET mux_asset_id = ?, mux_status = ? WHERE id = ?',
      [asset.id, asset.status, video_id]
    );

    await connection.end();
    return { statusCode: 200, body: 'Video submitted to Mux' };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: 'Error submitting to Mux' };
  }
};