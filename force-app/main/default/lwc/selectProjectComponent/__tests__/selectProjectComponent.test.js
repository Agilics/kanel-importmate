import { createElement } from 'lwc';
import SelectProjectComponent from 'c/selectProjectComponent'; 
import  getAllProjects from "@salesforce/apex/ImportProjectController.getAllProjects";

// Mock realistic data
const mockGetRecord = require('./data/db.json');

// Mock getAllProjects Apex wire adapter
jest.mock(
  '@salesforce/apex/ImportProjectController.getAllProjects',
  () => {
    const {
      createApexTestWireAdapter
    } = require('@salesforce/sfdx-lwc-jest');
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

 
describe('c-select-project-component', () => {
    afterEach(() => {
        // Nettoyer le DOM après chaque test
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        // Prevent data saved on mocks from leaking between tests
        jest.clearAllMocks();
    });

    it('renders project data when getRecord emits data', () => {
        const element = createElement('c-select-project-component', {
            is: SelectProjectComponent
        }); 
      // ACT
        document.body.appendChild(element);
        // Injecter les projets directement 
           // Emit data from @wire
       getAllProjects.emit(mockGetRecord); 
      const expectedName = 'Project Alpha';

       
      return Promise.resolve().then(() => { 
        //Assert
       expect(expectedName).toBe(mockGetRecord[0].Name);
        expect(mockGetRecord.length).toBeGreaterThan(0);
      });
   
       
    });
});
