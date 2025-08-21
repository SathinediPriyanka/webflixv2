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
      port:3306,
      user: 'admin',
      password: process.env.RDS_PASSWORD,
      database: 'video_platform'
    });
    

    // Stream CSV from S3
    const stream = s3.getObject({ Bucket: bucket, Key: key }).createReadStream().pipe(csv());
     console.log('CSV crawling started');
     console.log(`Bucket: ${bucket}, Key: ${key}`);
     console.log(`Stream: ${stream}`);
    const promises = [];
    // stream.pipe(csv())
    //   .on('data', async (row) => {
    //     // Insert video metadata
    //     console.log(`Row: ${JSON.stringify(row)}`);
    //     const [result] = await connection.execute(
    //       'INSERT INTO videos (title, description, source_type, s3_url) VALUES (?, ?, ?, ?)',
    //       [row.title || 'Untitled', row.description || '', 'csv', row.s3_url]
    //     );
    //     console.log(`Inserted video with ID: ${result.insertId}`);
    //     // Collect for Mux submission
    //     promises.push({
    //       video_id: result.insertId,
    //       s3_url: row.s3_url
    //     });
    //   })
    //   .on('end', async () => {
    //     await connection.end();
    //     console.log('CSV crawling completed');
    //     // Trigger Mux submission Lambda
    //     const lambda = new AWS.Lambda();
    //     for (const item of promises) {
    //       await lambda.invoke({
    //         FunctionName: 'video-platform-mux-submitter',
    //         InvocationType: 'Event',
    //         Payload: JSON.stringify(item)
    //       }).promise();
    //     }
    //     console.log('Mux submission Lambda triggered');
    //   });
    for await (const row of stream) {
      console.log('Full row:', JSON.stringify(row));
      console.log(row.title,row.description,row.s3_url);

      const [result] = await connection.execute(
        'INSERT INTO videos (title, description, source_type, s3_url) VALUES (?, ?, ?, ?)',
        [row.title || 'Untitled', row.description || '', 'csv', row.s3_url]
      );

      console.log(`Inserted video with ID: ${result.insertId}`);

      promises.push({
        video_id: result.insertId,
        s3_url: row.s3_url
      });
    }

    await connection.end();
    console.log('CSV crawling completed');

    // Trigger Mux submission Lambda
    const lambda = new AWS.Lambda();
    for (const item of promises) {
      await lambda.invoke({
        FunctionName: 'video-platform-mux-submitter',
        InvocationType: 'Event',
        Payload: JSON.stringify(item)
      }).promise();
    }

    console.log('Mux submission Lambda triggered');

    return { statusCode: 200, body: 'CSV processed' };
  } catch (error) {
    console.error(error);
    return { statusCode: 500, body: 'Error processing CSV' };
  }
};