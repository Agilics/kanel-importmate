import { createElement } from "lwc";
import { getRecord } from 'lightning/uiRecordApi';
import SelectProjectComponent from "c/selectProjectComponent"; 
import searchProjectsByName from '@salesforce/apex/ImportProjectController.searchProjectsByName';

// Mock Apex
jest.mock(
  '@salesforce/apex/ImportProjectController.searchProjectsByName',
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);
 // Mock realistic data
const mockProjects = require('./data/db.json');
describe("c-select-project-component", () => {
  afterEach(() => {
    // Nettoyer le DOM après chaque test
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    } 
  });
  jest.clearAllMocks();

    it('displays label in the header', () => {
        // Create component and set the header public property
        const element = createElement('c-select-project-component', {
            is: SelectProjectComponent
        });
        element.title = 'Select a project';
        document.body.appendChild(element);
        const mockFn = jest.fn();
        // Validate the modal header to have rendered with correct label
        expect(
            element.shadowRoot.querySelector('lightning-modal-header').label
        ).toBe('Select a project');     
    });

    
     it('renders project table when projects are available',async () => {
    const element = createElement('c-select-project-component', {
      is: SelectProjectComponent
    });
    element.projects = mockProjects;
    element.project = mockProjects[0];

    document.body.appendChild(element);
    searchProjectsByName.mockResolvedValue([
      {
        Id: '001',
        Name: 'Project Alpha',
        TargetObject__c: 'Contact',
        Description__c: 'Import contacts'
      }
    ]);

    // Attends que le DOM se mette à jour
    await  Promise.resolve();
    
    expect(element.projects.length).toBe(2);
    expect(element.project.Name).toContain('Project Alpha');
    
      
  });
    
  
  it("hasNoProjects is true when there's no project",async () => {
    const element = createElement("c-select-project-component", {
      is: SelectProjectComponent
    });
    return Promise.resolve().then(()=>{
      element.projects = [];
      expect(element.hasNoProjects).toBeTruthy();
    });
  });

  it("hasNoProjects is false when there're  projects",async () => {
    const element = createElement("c-select-project-component", {
      is: SelectProjectComponent
    });
    
      element.projects = mockProjects;
    document.body.appendChild(element);


      return Promise.resolve().then(()=>{
        expect(element.hasNoProjects).not.toBeTruthy();
      });
  });

  
});
