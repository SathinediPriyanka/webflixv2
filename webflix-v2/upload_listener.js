const AWS = require('aws-sdk');
const mysql2 = require('mysql2/promise');
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const bucket = event.Records[0].s3.bucket.name;
  const key = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  
  try {
    // Create DB connection
    const connection = await mysql2.createConnection({
      host: process.env.RDS_HOST,
      port:process.env.RDS_PORT,
      user: 'admin',
      password: process.env.RDS_PASSWORD,
      database: 'video_platform'
    });

    // Get metadata from S3 tags or sidecar JSON
    const tags = await s3.getObjectTagging({ Bucket: bucket, Key: key }).promise();
    const metadata = {
      title: tags.TagSet.find(t => t.Key === 'title')?.Value || key,
      description: tags.TagSet.find(t => t.Key === 'description')?.Value || ''
    };

    // Insert video metadata
    const [result] = await connection.execute(
      'INSERT INTO videos (title, description, source_type, s3_url) VALUES (?, ?, ?, ?)',
      [metadata.title, metadata.description, 'upload', `s3://${bucket}/${key}`]
    );

    await connection.end();

    // Trigger Mux submission
    const lambda = new AWS.Lambda();
    await lambda.invoke({
      FunctionName: 'video-platform-mux-submitter',
      InvocationType: 'Event',
      Payload: JSON.stringify({
        video_id: result.insertId,
        s3_url: `https://${bucket}.s3.us-east-1.amazonaws.com/${key}`
      })
    }).promise();

    return { statusCode: 200, body: 'Upload processed' };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: 'Error processing upload' };
  }
};