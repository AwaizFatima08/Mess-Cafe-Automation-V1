const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const collectionName = process.argv[2];
if (!collectionName) {
  console.error('Usage: node import_collection.js <collection_name>');
  process.exit(1);
}

const csvFilePath = path.join(__dirname, 'csv', `${collectionName}.csv`);

function parseValue(value) {
  if (value === undefined || value === null) return null;

  const trimmed = String(value).trim();

  if (trimmed === '') return null;

  if (trimmed.toLowerCase() === 'true') return true;
  if (trimmed.toLowerCase() === 'false') return false;

  if (trimmed.toLowerCase() === 'null') return null;

  if (
    (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
    (trimmed.startsWith('{') && trimmed.endsWith('}'))
  ) {
    try {
      return JSON.parse(trimmed);
    } catch (e) {
      return trimmed;
    }
  }

  if (/^-?\d+(\.\d+)?$/.test(trimmed)) {
    return Number(trimmed);
  }

  return trimmed;
}

const results = [];

fs.createReadStream(csvFilePath)
  .pipe(csv())
  .on('data', (data) => results.push(data))
  .on('end', async () => {
    try {
      for (const row of results) {
        const docId = row.docId ? String(row.docId).trim() : '';

        if (!docId) {
          console.warn('Skipping row with missing docId:', row);
          continue;
        }

        const docData = {};

        for (const key of Object.keys(row)) {
          const cleanKey = String(key).trim();

          if (!cleanKey || cleanKey === 'docId') continue;

          docData[cleanKey] = parseValue(row[key]);
        }

        await db.collection(collectionName).doc(docId).set(docData);
        console.log(`Uploaded document: ${docId}`);
      }

      console.log(`Import completed for collection: ${collectionName}`);
    } catch (error) {
      console.error('Import failed:', error);
    }
  });
