import { createElement } from 'lwc';
import ProjectCreatorComponent from 'c/projectCreatorComponent';

// Mock de la méthode Apex
import getCompatibleSObjects from '@salesforce/apex/ObjectMetadataController.getCompatibleSObjects';
jest.mock(
    '@salesforce/apex/ObjectMetadataController.getCompatibleSObjects',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

describe('c-project-creator-component', () => {
    afterEach(() => {
        // Nettoyer le DOM après chaque test
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders static title', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        const heading = element.shadowRoot.querySelector('h2.title');
        expect(heading.textContent).toBe('New project');
    });

    it('calls Apex getCompatibleSObjects on connectedCallback and sets options', async () => {
        // Simuler une réponse Apex
        getCompatibleSObjects.mockResolvedValue(['Account', 'Contact']);

        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        // attendre la fin de la promesse
        await Promise.resolve();

        expect(getCompatibleSObjects).toHaveBeenCalled();
        expect(element.options).toEqual([
            { label: 'Account', value: 'Account' },
            { label: 'Contact', value: 'Contact' }
        ]);
    });

    it('dispatches namechange event when project name changes', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('namechange', handler);

        const input = element.shadowRoot.querySelector('lightning-input');
        input.dispatchEvent(new CustomEvent('change', { detail: 'My Project' }));

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail).toBe('My Project');
    });

    it('dispatches descriptionchange event when description changes', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('descriptionchange', handler);

        const textarea = element.shadowRoot.querySelector('lightning-textarea');
        textarea.dispatchEvent(new CustomEvent('change', { detail: 'Some text' }));

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail).toBe('Some text');
    });

    it('dispatches targetchange event when target object changes', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('targetchange', handler);

        const combobox = element.shadowRoot.querySelector('lightning-combobox');
        combobox.dispatchEvent(new CustomEvent('change', { detail: 'Account' }));

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail).toBe('Account');
    });

    it('getter isTargetObjetSelected returns true when targetObject is set', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        element.targetObject = 'Account';
        expect(element.isTargetObjetSelected).toBe(true);

        element.targetObject = '';
        expect(element.isTargetObjetSelected).toBe(false);
    });

    it('dispatches save event with project details when Save Project button clicked', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        element.projectName = 'Proj 1';
        element.description = 'Desc 1';
        element.targetObject = 'Account';

        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('save', handler);

        const button = element.shadowRoot.querySelector('button.btn-save');
        button.click();

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail).toEqual({
            projectName: 'Proj 1',
            description: 'Desc 1',
            targetObject: 'Account'
        });
    });

    it('dispatches cancel event when Cancel button clicked', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        //simulation 
        const handler = jest.fn();
        element.addEventListener('cancel', handler);

        const button = element.shadowRoot.querySelector('button.btn-cancel');
        button.click();

        expect(handler).toHaveBeenCalled();
    });

    it('resetFields clears input values', () => {
        const element = createElement('c-project-creator-component', {
            is: ProjectCreatorComponent
        });
        document.body.appendChild(element);

        // Simuler des valeurs dans inputs
        const inputs = element.shadowRoot.querySelectorAll('.rounded-input');
        inputs.forEach((input) => {
            input.value = 'Some value';
        });

        // Appeler la méthode publique
        element.resetFields();

        inputs.forEach((input) => {
            expect(input.value).toBe('');
        });
    });
});
