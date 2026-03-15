const admin = require('firebase-admin');
const { createObjectCsvWriter } = require('csv-writer');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const collectionName = process.argv[2];
if (!collectionName) {
  console.error('Usage: node export_collection.js <collectionName>');
  process.exit(1);
}

const outputFile = path.join(__dirname, 'csv', `${collectionName}.csv`);

function flattenValue(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') return JSON.stringify(value);
  return value;
}

async function exportCollection() {
  try {
    const snapshot = await db.collection(collectionName).get();

    if (snapshot.empty) {
      console.log(`No documents found in collection: ${collectionName}`);
      return;
    }

    const rows = [];
    const fieldSet = new Set(['docId']);

    snapshot.forEach((doc) => {
      const data = doc.data();
      const row = { docId: doc.id };

      Object.keys(data).forEach((key) => {
        row[key] = flattenValue(data[key]);
        fieldSet.add(key);
      });

      rows.push(row);
    });

    const headers = Array.from(fieldSet).map((field) => ({
      id: field,
      title: field,
    }));

    const normalizedRows = rows.map((row) => {
      const normalized = {};
      headers.forEach((header) => {
        normalized[header.id] = row[header.id] ?? '';
      });
      return normalized;
    });

    const writer = createObjectCsvWriter({
      path: outputFile,
      header: headers,
    });

    await writer.writeRecords(normalizedRows);

    console.log(`Export successful: ${outputFile}`);
    console.log(`Documents exported: ${rows.length}`);
  } catch (error) {
    console.error('Export failed:', error);
  }
}

exportCollection();
