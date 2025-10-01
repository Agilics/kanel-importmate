import { createElement } from "@lwc/engine-dom";
import MainComponent from "c/mainComponent";

describe("c-main-component", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("check  target object is selected",async () => {
    // Arrange
    const element = createElement("c-main-component", {
      is: MainComponent
    });
    element.targetObject ='account';
    // Act
    document.body.appendChild(element);

    // Assert 
   // expect(p).toContain('Target Object:');
    await Promise.resolve();

        const p = element.shadowRoot.querySelector('p');
        expect(p.textContent).not.toBeNull();
      expect(element.isTargetObjetSelected).toBeTruthy();
      expect(element.targetObject.textContent).toBe('Account');
  
  });
});
