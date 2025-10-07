import { createElement } from "@lwc/engine-dom";
import ImportProjectRecentComponent from "c/importProjectRecentComponent";

// Mock realistic data
//const mockProjects = require('./data/projects.json');
describe("c-import-project-recent-component", () => {
  //Clean Up Between Tests
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

    
});
