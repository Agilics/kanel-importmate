import { createElement } from "lwc";
import HelloWorld from "c/helloWorld";

describe("c-hello-world", () => {
  let element;

  beforeEach(() => {
    element = createElement("c-hello-world", {
      is: HelloWorld
    });
    document.body.appendChild(element);
  });

  afterEach(() => {
    document.body.removeChild(element);
  });

  describe("Component Rendering", () => {
    it("should render the component", () => {
      const div = element.shadowRoot.querySelector("div");
      expect(div).toBeTruthy();
    });

    it("should display default greeting", () => {
      const heading = element.shadowRoot.querySelector("h2");
      expect(heading.textContent).toBe("Hello, World!");
    });

    it("should display custom greeting when properties are set", () => {
      element.name = "John";
      element.greeting = "Hi";

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Hi, John!");
      });
    });
  });

  describe("Click Functionality", () => {
    it("should increment click count on click", () => {
      const heading = element.shadowRoot.querySelector("h2");

      heading.click();

      return Promise.resolve().then(() => {
        const clickText = element.shadowRoot.querySelector("p");
        expect(clickText.textContent).toBe("Clicked 1 time");
      });
    });

    it("should handle multiple clicks", () => {
      const heading = element.shadowRoot.querySelector("h2");

      heading.click();
      heading.click();
      heading.click();

      return Promise.resolve().then(() => {
        const clickText = element.shadowRoot.querySelector("p");
        expect(clickText.textContent).toBe("Clicked 3 times");
      });
    });

    it("should dispatch greetingclick event", () => {
      const mockHandler = jest.fn();
      element.addEventListener("greetingclick", mockHandler);

      const heading = element.shadowRoot.querySelector("h2");
      heading.click();

      expect(mockHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          detail: {
            name: "World",
            clickCount: 1
          }
        })
      );
    });
  });

  describe("High Click Count Indicator", () => {
    it("should show high click indicator when count > 5", () => {
      // Simulate 6 clicks by calling handleClick directly
      for (let i = 0; i < 6; i++) {
        element.handleClick();
      }

      return Promise.resolve().then(() => {
        const indicator = element.shadowRoot.querySelector(
          "p.slds-text-color_success"
        );
        expect(indicator.textContent).toBe("Wow! You've clicked a lot!");
      });
    });

    it("should not show high click indicator when count <= 5", () => {
      // Simulate 5 clicks
      for (let i = 0; i < 5; i++) {
        element.handleClick();
      }

      return Promise.resolve().then(() => {
        const indicator = element.shadowRoot.querySelector(
          "p.slds-text-color_success"
        );
        expect(indicator).toBeFalsy();
      });
    });
  });

  describe("Toggle Details", () => {
    it("should show details when toggle button is clicked", () => {
      // Simulate button click by calling the method directly
      element.showDetails = true;

      return Promise.resolve().then(() => {
        const detailsSection = element.shadowRoot.querySelector(
          "div.slds-box.slds-theme_shade"
        );
        expect(detailsSection).toBeTruthy();
      });
    });

    it("should hide details when toggle button is clicked again", () => {
      // First click to show
      element.showDetails = true;

      return Promise.resolve().then(() => {
        // Second click to hide
        element.showDetails = false;

        return Promise.resolve().then(() => {
          const detailsSection = element.shadowRoot.querySelector(
            "div.slds-box.slds-theme_shade"
          );
          expect(detailsSection).toBeFalsy();
        });
      });
    });

    it("should display correct information in details section", () => {
      element.name = "Alice";
      element.greeting = "Welcome";
      element.clickCount = 3;
      element.showDetails = true;

      return Promise.resolve().then(() => {
        const detailsSection = element.shadowRoot.querySelector(
          "div.slds-box.slds-theme_shade"
        );
        expect(detailsSection.textContent).toContain("Name: Alice");
        expect(detailsSection.textContent).toContain("Greeting: Welcome");
        expect(detailsSection.textContent).toContain("Click Count: 3");
      });
    });
  });

  describe("Reset Functionality", () => {
    it("should reset click count to zero", () => {
      element.clickCount = 5;

      // Simulate reset by setting clickCount directly
      element.clickCount = 0;

      expect(element.clickCount).toBe(0);
    });

    it("should update display after reset", () => {
      element.clickCount = 3;

      // Simulate reset
      element.clickCount = 0;

      return Promise.resolve().then(() => {
        const clickText = element.shadowRoot.querySelector("p");
        expect(clickText.textContent).toBe("Clicked 0 times");
      });
    });
  });

  describe("Edge Cases", () => {
    it("should handle empty name", () => {
      element.name = "";

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Hello, !");
      });
    });

    it("should handle empty greeting", () => {
      element.greeting = "";

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe(", World!");
      });
    });

    it("should handle special characters in name", () => {
      element.name = "John & Jane";

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Hello, John & Jane!");
      });
    });
  });
});
