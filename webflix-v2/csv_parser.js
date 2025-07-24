const AWS = require('aws-sdk');
const csv = require('csv-parser');
const mysql2 = require('mysql2/promise');
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const bucket = event.Records[0].s3.bucket.name;
  const key = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
  
  try {
    // Create DB connection
    const connection = await mysql2.createConnection({
      host: process.env.RDS_HOST,
      user: 'admin',
      password: process.env.RDS_PASSWORD,
      database: 'video_platform'
    });

    // Stream CSV from S3
    const stream = s3.getObject({ Bucket: bucket, Key: key }).createReadStream();
    
    const promises = [];
    stream.pipe(csv())
      .on('data', async (row) => {
        // Insert video metadata
        const [result] = await connection.execute(
          'INSERT INTO videos (title, description, source_type, s3_url) VALUES (?, ?, ?, ?)',
          [row.title || 'Untitled', row.description || '', 'csv', row.s3_url]
        );
        
        // Collect for Mux submission
        promises.push({
          video_id: result.insertId,
          s3_url: row.s3_url
        });
      })
      .on('end', async () => {
        await connection.end();
        
        // Trigger Mux submission Lambda
        const lambda = new AWS.Lambda();
        for (const item of promises) {
          await lambda.invoke({
            FunctionName: 'video-platform-mux-submitter',
            InvocationType: 'Event',
            Payload: JSON.stringify(item)
          }).promise();
        }
      });

    return { statusCode: 200, body: 'CSV processed' };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: 'Error processing CSV' };
  }
};