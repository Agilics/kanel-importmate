import { createElement } from "lwc";
import ProjectDetailViewComponent from 'c/projectDetailViewComponent';
import {expect, jest, test} from '@jest/globals';
import {getRecord} from 'lightning/uiRecordApi';
import  searchProjetById from "@salesforce/apex/ImportProjectController. searchProjetById";
import  getAllProjects from "@salesforce/apex/ImportProjectController.getAllProjects";

//mock données fictives
const mockProject = {
    Id: '002',
    Name: 'Project Beta',
    TargetObject__c: 'Account',
    Description__c: 'This is a test project'
};
 
 
describe("c-project-detail-view-component", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
     // Prevent data saved on mocks from leaking between tests
    jest.clearAllMocks();
  });

  it("renders the component", () => {
     const element = createElement("c-project-detail-view-component", {
      is: ProjectDetailViewComponent
    });

    // Set @api project property
        element.project = mockProject;
      
 
    const expectedId= '002';
    const expectedName ='Project Beta';
    const div = element.shadowRoot.querySelector('pre#projectName');
    return Promise.resolve().then(() => { 
  // Query DOM elements
            const nameElement = element.shadowRoot.querySelector('pre#projectName');
            const targetObjectElement = element.shadowRoot.querySelector('pre#target');
            const descriptionElement = element.shadowRoot.querySelector('pre#desc'); 
            // Assertions
            expect(element.project).not.toBeNull();
            expect( expectedName).toBe(mockProject.Name);
            
    });
  });
});
