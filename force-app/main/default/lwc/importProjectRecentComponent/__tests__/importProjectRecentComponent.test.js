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

  it("fetch the recents imported projects", () => {
    // Arrange
    const element = createElement("c-import-project-recent-component", {
      is: ImportProjectRecentComponent
    });
    document.body.appendChild(element);

    //then
    expect(element.projects[0].Name).toBe("Import Project Alpha");
  });

  it("hasNoProjects is true when there's no project", async () => {
    //given
    const element = createElement("c-import-project-recent-component", {
      is: ImportProjectRecentComponent
    });

    return Promise.resolve().then(() => {
      //when
      element.projects = [];

      // then assertions
      expect(element.hasNoProjects).toBeTruthy();
    });
  });
});
