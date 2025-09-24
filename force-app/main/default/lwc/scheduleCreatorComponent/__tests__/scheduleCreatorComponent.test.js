import { createElement } from 'lwc';
import ScheduleCreatorComponent from 'c/scheduleCreatorComponent';

// Mock Apex
import getPickListValues from '@salesforce/apex/ObjectMetadataController.getPickListValues';
jest.mock(
    '@salesforce/apex/ObjectMetadataController.getPickListValues',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

// Helper pour simuler le @wire
const flushPromises = () => new Promise(setImmediate);

describe('c-schedule-creator-component', () => {
    afterEach(() => {
        // Nettoyer le DOM après chaque test
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders static title', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        document.body.appendChild(element);

        // Vérifie que le titre s'affiche correctement
        const heading = element.shadowRoot.querySelector('h2.title');
        expect(heading.textContent).toBe('New schedule');
    });

    it('renders readonly projectId input', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        element.projectId = '12345';
        document.body.appendChild(element);

        const input = element.shadowRoot.querySelector('lightning-input[name="projectId"]');
        expect(input.value).toBe('12345');
        expect(input.readOnly).toBe(true);
    });

    it('sets picklist values from @wire', async () => {
        // Simuler les données renvoyées par Apex
        const mockData = { Daily: 'Daily', Weekly: 'Weekly' };
        getPickListValues.mockResolvedValue(mockData);

        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        document.body.appendChild(element);

        // attendre que le @wire se résolve
        await flushPromises();

        expect(element.picklistValues).toEqual([
            { label: 'Daily', value: 'Daily' },
            { label: 'Weekly', value: 'Weekly' }
        ]);
    });

    it('fires select event on combobox change', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('select', handler);

        const combobox = element.shadowRoot.querySelector('lightning-combobox');

        // Simuler le changement de valeur
        combobox.dispatchEvent(new CustomEvent('change', { detail: { value: 'Daily' } }));

        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail).toEqual({ frequency: 'Daily' });
    });

    it('getter isSelectedFrequency returns true if selectedFrequency is set', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        element.selectedFrequency = 'Weekly';
        expect(element.isSelectedFrequency).toBe(true);

        element.selectedFrequency = '';
        expect(element.isSelectedFrequency).toBe(false);
    });

    it('shows <p> when frequency is selected', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        element.selectedFrequency = 'Monthly';
        document.body.appendChild(element);

        const paragraph = element.shadowRoot.querySelector('p');
        expect(paragraph.textContent).toBe('Frequency: Monthly');
    });

    it('dispatches add event when Add Schedule button clicked', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('add', handler);

        const button = element.shadowRoot.querySelector('button.btn-save');
        button.click();

        expect(handler).toHaveBeenCalled();
    });

    it('dispatches cancel event when Cancel button clicked', () => {
        const element = createElement('c-schedule-creator-component', { is: ScheduleCreatorComponent });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('cancel', handler);

        const button = element.shadowRoot.querySelector('button.btn-cancel');
        button.click();

        expect(handler).toHaveBeenCalled();
    });
});
