const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");
module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    // Jest mocks
    "^@salesforce/apex$": "<rootDir>/force-app/test/jest-mocks/apex",
    "^@salesforce/schema$": "<rootDir>/force-app/test/jest-mocks/schema",
    "^lightning/navigation$":
      "<rootDir>/force-app/test/jest-mocks/lightning/navigation",
    "^lightning/platformShowToastEvent$":
      "<rootDir>/force-app/test/jest-mocks/lightning/platformShowToastEvent",
    "^lightning/uiRecordApi$":
      "<rootDir>/force-app/test/jest-mocks/lightning/uiRecordApi",
    "^lightning/messageService$":
      "<rootDir>/force-app/test/jest-mocks/lightning/messageService",
    "^lightning/actions$":
      "<rootDir>/force-app/test/jest-mocks/lightning/actions",
    "^lightning/modal$": "<rootDir>/force-app/test/jest-mocks/lightning/modal",

    "^lightning/modalHeader$":
      "<rootDir>/force-app/test/jest-mocks/lightning/modalHeader.js",
    "^lightning/modalBody$":
      "<rootDir>/force-app/test/jest-mocks/lightning/modalBody.js",
    "^lightning/modalFooter$":
      "<rootDir>/force-app/test/jest-mocks/lightning/modalFooter.js",
    "^lightning/refresh$":
      "<rootDir>/force-app/test/jest-mocks/lightning/refresh",
    "^lightning/logger$": "<rootDir>/force-app/test/jest-mocks/lightning/logger"
  },
  testTimeout: 10000
};
