import express from 'express';
import * as bodyParser from 'body-parser';
import cors from 'cors';
import fileUpload from 'express-fileupload';

import fs from 'fs';
import gm from 'gm';
import childProcess from 'child_process';

import shortid from 'shortid';
import _ from 'lodash';

enum FieldType {
  Text = 'TEXT',
  Number = 'NUMBER',
  Checkbox = 'CHECKBOX',
  Date = 'DATE',
  Section = 'SECTION',
}

interface IField {
  id: string;
  type: FieldType;
  position?: number[];
  prompt: string;
}

const PORT = process.env.PORT || 5000;
const app = express();

const fields: IField[] = [
  {
    id: 'intro',
    type: FieldType.Section,
    position: [],
    prompt: '1040 U.S. individual income tax return 2018',
  },
  {
    id: 'filingStatus',
    type: FieldType.Section,
    position: [],
    prompt: 'Filing status',
  },
  {
    id: 'single',
    type: FieldType.Checkbox,
    position: [562, 440],
    prompt: 'single',
  },
  {
    id: 'marriedJointly',
    type: FieldType.Checkbox,
    position: [808, 440],
    prompt: 'married filing jointly',
  },
  {
    id: 'marriedSeparately',
    type: FieldType.Checkbox,
    position: [1250, 442],
    prompt: 'married filing separately',
  },
  {
    id: 'headOfHousehold',
    type: FieldType.Checkbox,
    position: [1778, 434],
    prompt: 'head of household',
  },
  {
    id: 'qualifyingWidower',
    type: FieldType.Checkbox,
    position: [2226, 428],
    prompt: 'qualifying widow(er)',
  },
  {
    id: 'firstName',
    type: FieldType.Text,
    position: [244, 560],
    prompt: 'your first name and initial',
  },
  {
    id: 'lastName',
    type: FieldType.Text,
    position: [1398, 560],
    prompt: 'last name',
  },
  {
    id: 'social',
    type: FieldType.Number,
    position: [2688, 560],
    prompt: 'your social security number',
  },
  {
    id: 'standardDeduction',
    type: FieldType.Section,
    position: [],
    prompt: 'your standard deduction'
  },
  {
    id: 'dependent',
    type: FieldType.Checkbox,
    position: [764, 642],
    prompt: 'someone can claim you as a dependent',
  },
  {
    id: 'bornBefore1954',
    type: FieldType.Checkbox,
    position: [1618, 640],
    prompt: 'you were born before january 2, 1954',
  },
  {
    id: 'blind',
    type: FieldType.Checkbox,
    position: [2462, 636],
    prompt: 'you are blind',
  },
  {
    id: 'spouseFirstName',
    type: FieldType.Text,
    position: [],
    prompt: 'if joint return, spouse\'s first name and initial',
  },
  {
    id: 'spouseLastName',
    type: FieldType.Text,
    position: [],
    prompt: 'last name',
  },
  {
    id: 'spouseSocial',
    type: FieldType.Number,
    position: [],
    prompt: 'spouse\'s social security number',
  },
  {
    id: 'spouseStandardDeduction',
    type: FieldType.Section,
    position: [],
    prompt: 'Spouse standard deduction'
  },
  {
    id: 'spouseDependent',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'someone can claim your spouse as a dependent',
  },
  {
    id: 'spouseBornBefore1954',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'spouse was born before january 2, 1954',
  },
  {
    id: 'spouseBlind',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'spouse is blind',
  },
  {
    id: 'spouseItemizesSeparate',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'spouse itemizes on a separate return or you were dual-status alien',
  },
  {
    id: 'fullYearHealth',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'full-year health care coverage or exempt (see inst.)',
  },
  {
    id: 'address',
    type: FieldType.Text,
    position: [250, 1042],
    prompt: 'home address (number and street). If you have a P.O. box, see instructions'
  },
  {
    id: 'apartment',
    type: FieldType.Text,
    position: [2408, 1034],
    prompt: 'apt. no.',
  },
  {
    id: 'city',
    type: FieldType.Text,
    position: [254, 1178],
    prompt: 'city, town or post office, state, and ZIP code. If you have a foreign address, attach Schedule 6.',
  },
  {
    id: 'presidentialCampaign',
    type: FieldType.Section,
    position: [],
    prompt: 'Presidential Election Campaign'
  },
  {
    id: 'presidentialCampaignYou',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'you',
  },
  {
    id: 'presidentialCampaignSpouse',
    type: FieldType.Checkbox,
    position: [],
    prompt: 'spouse',
  },
  {
    id: 'occupation',
    type: FieldType.Text,
    position: [1870, 1806],
    prompt: 'your occupation',
  },
  {
    id: 'spouseOccupation',
    type: FieldType.Text,
    position: [],
    prompt: 'spouse\'s occupation',
  },
];

const fieldsObj = _.keyBy(fields, 'id');

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
app.use(bodyParser.urlencoded({ limit: '50mb', extended: true }));
app.use(fileUpload());
app.use(cors(corsOptionsDelegate));

app.post('/perspective', (req, res) => {
  if (!req.files || !req.files.file) {
    res.status(400).json({ success: false, error: 'Please provide the image file.' });
    return;
  }

  const corners = [
    [56, 240],
    [3212, 156],
    [76, 4264],
    [3252, 4352],
  ].map((pair) => `${pair[0]},${pair[1]}`);

  const perspectiveShift = `${corners[0]} 0,0  ${corners[1]} 3485,0  ${corners[2]} 0,4510  ${corners[3]} 3485,4510`;

  const file = req.files['file'] as fileUpload.UploadedFile;

  const fileName = `${shortid.generate()}-${file.name}`;
  const path = `/tmp/${fileName}`
  const outPath = `/tmp/o_${fileName}`

  file.mv(path);
  const cp = childProcess.exec(`convert ${path} -distort Perspective "${perspectiveShift}" ${outPath}`);

  cp.on('close', () => {
    gm(outPath)
      .crop(3485, 4510, 0, 0)
      .toBuffer('jpg', (err, buffer) => {
        if (err) res.status(500).json({ success: false, error: `Image processing error: ${err}` });

        res.writeHead(200, {'Content-Type': 'image/jpeg'});
        res.end(buffer);

        fs.unlink(path, () => {});
        fs.unlink(outPath, () => {});
      });
  });
});

app.post('/questions', (req, res) => {
  if (!req.files || !req.files.file) {
    res.status(400).json({ success: false, error: 'Please provide the image file.' });
    return;
  }

  (req.files.file as fileUpload.UploadedFile).mv('/tmp/test.jpg');

  res.status(200).json({ fields });
});

app.post('/process', (req, res) => {
  if (!req.files || !req.files.file) {
    res.status(400).json({ success: false, error: 'Please provide the image file.' });
    return;
  }

  const file = req.files['file'] as fileUpload.UploadedFile;

  const answers = {
    single: 'yes',
    headOfHousehold: 'no',
    marriedJointly: 'no',
    marriedSeparately: 'no',
    qualifyingWidower: 'no',
    firstName: 'david z',
    lastName: 'shen',
    social: '123456789',
    dependent: 'yes',
    bornBefore1954: 'no',
    blind: 'no',
    spouseFirstName: '',
    spouseLastName: '',
    spouseSocial: '',
    spouseDependent: '',
    spouseBornBefore1954: '',
    spouseBlind: '',
    spouseItemizesSeparate: '',
    fullYearHealth: '',
    address: '24 tip top street',
    apartment: '',
    city: 'brighton ma 02135',
    presidentialCampaignYou: 'no',
    presidentialCampaignSpouse: 'no',
    occupation: 'student',
    spouseOccupation: '',
  };

  const image = gm(file.data, file.name)
    .fontSize(48)
    .font(`${process.env.HOME}/.fonts/roboto/Roboto-Thin.ttf`)
    .gravity('NorthWest')
    .stroke('#000000');

  _.forOwn(answers, (value, key) => {
    const field = fieldsObj[key];
    if (!field) return;

    let answer = value;
    switch(field.type) {
      case FieldType.Checkbox:
        answer = value.toLowerCase() === 'yes' ? 'X' : '';
        break;
      case FieldType.Text:
        const numWords = value.split(' ').length;
        if (numWords > 5) {
          break;
        }
        answer = value.split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase()).join(' ');
        break;
    }

    image.drawText(field.position![0], field.position![1], answer);
  });

  image.toBuffer('jpg', (err, buffer) => {
    if (err) res.status(500).json({ success: false, error: `Image processing error: ${err}` });

    res.writeHead(200, {'Content-Type': 'image/jpeg'});
    res.end(buffer);
  });
});

app.listen(PORT, () => {
  console.log(`Listening on port ${PORT}.`);
});
