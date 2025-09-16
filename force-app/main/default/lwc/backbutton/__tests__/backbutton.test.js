import { createElement } from "@lwc/engine-dom";
import Backbutton from "c/backbutton";

describe("c-backbutton", () => {
  afterEach(() => {
    // Clean up the DOM between tests
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders a back button", () => {
    const element = createElement("c-backbutton", {
      is: Backbutton
    });
    document.body.appendChild(element);

    // Verify the button exists and contains the word 'Back'
    const button = element.shadowRoot.querySelector("button.back-btn");
    expect(button).not.toBeNull();
    expect(button.textContent).toContain("Back");
  });

  it("dispatches a back event when clicked", () => {
    const element = createElement("c-backbutton", {
      is: Backbutton
    });

    // Attach a listener to the custom event
    const handler = jest.fn();
    element.addEventListener("back", handler);

    document.body.appendChild(element);

    // Simulate a click on the button
    const button = element.shadowRoot.querySelector("button.back-btn");
    button.click();

    // Verify the event was dispatched exactly once
    expect(handler).toHaveBeenCalledTimes(1);
  });
});
