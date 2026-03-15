const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const collectionName = process.argv[2];

if (!collectionName) {
  console.error('Usage: node import_collection.js <collectionName>');
  process.exit(1);
}

const inputFile = path.join(__dirname, 'csv', `${collectionName}.csv`);

function parseValue(value) {
  if (value === undefined || value === null || value === '') return null;

  if (value === 'true') return true;
  if (value === 'false') return false;

  if (!isNaN(value) && value.toString().trim() !== '') {
    return Number(value);
  }

  return value;
}

async function importCollection() {
  const rows = [];

  fs.createReadStream(inputFile)
    .pipe(csv())
    .on('data', (row) => rows.push(row))
    .on('end', async () => {
      try {
        let successCount = 0;

        for (const row of rows) {
          const docId = row.docId?.trim();

          if (!docId) {
            console.log('Skipped row without docId:', row);
            continue;
          }

          const data = {};

          for (const key of Object.keys(row)) {
            if (key === 'docId') continue;
            data[key] = parseValue(row[key]);
          }

          await db.collection(collectionName).doc(docId).set(data);
          console.log(`Uploaded: ${docId}`);
          successCount++;
        }

        console.log(`Import completed. Total uploaded: ${successCount}`);
      } catch (error) {
        console.error('Import failed:', error);
      }
    })
    .on('error', (error) => {
      console.error('CSV read failed:', error);
    });
}

importCollection();
