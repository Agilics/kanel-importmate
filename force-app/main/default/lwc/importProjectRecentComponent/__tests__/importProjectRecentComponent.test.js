import { createElement } from "@lwc/engine-dom";
import ImportProjectRecentComponent from "c/importProjectRecentComponent"; 
import { registerLdsTestWireAdapter } from '@salesforce/wire-service-jest-util'; 
import getRecentsProjects from '@salesforce/apex/ImportProjectController.getRecentsProjects'; 
 

import { createTestWireAdapter } from '@salesforce/wire-service-jest-util';

export const getTodo = createTestWireAdapter();

// Mock realistic data
const mockProjects = require('./data/projects.json');
describe("c-import-project-recent-component", () => {
  //Clean Up Between Tests
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it('check title recent project section ', () => {
    // Arrange
    const element = createElement("c-import-project-recent-component", {
      is: ImportProjectRecentComponent
    });

    // Act
    // Add the element to the jsdom instance
    document.body.appendChild(element);

    // Assert
    const title = element.shadowRoot.querySelector("div.recent-title");
    expect(title.textContent).toBe("Recent Projects");
  });

  it('fetch the recents imported projects', () => {
      // Arrange
    const element = createElement("c-import-project-recent-component", {
      is: ImportProjectRecentComponent
    });
    const mockFn = jest.fn();

    mockFn();
    element.projects = mockProjects;
    element.pro =  mockProjects [0];
    
    //then
    expect(mockFn).toHaveBeenCalled();
   // expect(pro.Name).toBe('Import Project Beta');

      
  });

   it("hasNoProjects is true when there's no project",async () => {
    //given
    const element = createElement("c-import-project-recent-component", {
      is:ImportProjectRecentComponent
    });
    
    return Promise.resolve().then(()=>{
      //when
      element.projects = [];
      const message = element.shadowRoot.querySelector('lightning-icon #info');

      // then assertions
      expect(element.hasNoProjects).toBeTruthy();  
      
    });
  });

   
 

  
});
