import express from 'express';
import * as bodyParser from 'body-parser';
import cors from 'cors';
import fileUpload from 'express-fileupload';

// import fs from 'fs';
// import gm from 'gm';

const PORT = process.env.PORT || 5000;
const app = express();

const corsOptionsDelegate = (req: any, callback: any) => {
  let corsOptions = {
    origin: false,
    credentials: true,
  };

  const whitelist = [
    process.env.URL || 'http://localhost:3000',
  ];

  if (process.env.NODE_ENV !== 'production' || whitelist.indexOf(req.header('Origin')) !== -1) {
    corsOptions.origin = true; // reflect (enable) the requested origin in the CORS response
  }

  callback(null, corsOptions); // callback expects two parameters: error and options
};

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(fileUpload());
app.use(cors(corsOptionsDelegate));

app.post('/process', (req, res) => {
  if (!req.files || !req.files.file) {
    res.status(400).json({ success: false, error: 'Please provide the image file.' });
    return;
  }

  console.log(req.files.file);
  res.status(200).json({ success: true });

  // const image = '';
  // gm(image, 'image.png')
});

app.listen(PORT, () => {
  console.log(`Listening on port ${PORT}.`);
});
