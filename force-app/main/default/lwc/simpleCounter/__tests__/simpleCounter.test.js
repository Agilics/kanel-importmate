import { createElement } from "lwc";
import SimpleCounter from "c/simpleCounter";

describe("c-simple-counter", () => {
  let element;

  beforeEach(() => {
    element = createElement("c-simple-counter", {
      is: SimpleCounter
    });
    document.body.appendChild(element);
  });

  afterEach(() => {
    document.body.removeChild(element);
  });

  function getButtons() {
    return element.shadowRoot.querySelectorAll("button");
  }

  describe("Component Rendering", () => {
    it("should render the component", () => {
      const div = element.shadowRoot.querySelector("div");
      expect(div).toBeTruthy();
    });

    it("should display initial count", () => {
      const heading = element.shadowRoot.querySelector("h2");
      expect(heading.textContent).toBe("Count: 0");
    });

    it("should show even message for initial count", () => {
      const paragraph = element.shadowRoot.querySelector("p");
      expect(paragraph.textContent).toBe("The count is even");
    });
  });

  describe("Increment Functionality", () => {
    it("should increment count when increment button is clicked", () => {
      const incrementButton = getButtons()[0];
      incrementButton.click();

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Count: 1");
      });
    });

    it("should show odd message after increment", () => {
      const incrementButton = getButtons()[0];
      incrementButton.click();

      return Promise.resolve().then(() => {
        const paragraph = element.shadowRoot.querySelector("p");
        expect(paragraph.textContent).toBe("The count is odd");
      });
    });
  });

  describe("Decrement Functionality", () => {
    it("should decrement count when decrement button is clicked", () => {
      // First increment to have a positive number
      element.count = 5;

      const decrementButton = getButtons()[1];
      decrementButton.click();

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Count: 4");
      });
    });
  });

  describe("Reset Functionality", () => {
    it("should reset count to zero when reset button is clicked", () => {
      // First set count to a non-zero value
      element.count = 10;

      const resetButton = getButtons()[2];
      resetButton.click();

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Count: 0");
      });
    });

    it("should show even message after reset", () => {
      // First set count to an odd number
      element.count = 7;

      const resetButton = getButtons()[2];
      resetButton.click();

      return Promise.resolve().then(() => {
        const paragraph = element.shadowRoot.querySelector("p");
        expect(paragraph.textContent).toBe("The count is even");
      });
    });
  });

  describe("Multiple Operations", () => {
    it("should handle multiple increments", () => {
      const incrementButton = getButtons()[0];
      incrementButton.click();
      incrementButton.click();
      incrementButton.click();

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Count: 3");
      });
    });

    it("should handle increment then decrement", () => {
      const incrementButton = getButtons()[0];
      const decrementButton = getButtons()[1];
      incrementButton.click();
      decrementButton.click();

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Count: 0");
      });
    });
  });

  describe("Edge Cases", () => {
    it("should handle negative numbers", () => {
      element.count = -5;

      return Promise.resolve().then(() => {
        const heading = element.shadowRoot.querySelector("h2");
        expect(heading.textContent).toBe("Count: -5");
      });
    });

    it("should show odd message for negative odd numbers", () => {
      element.count = -3;

      return Promise.resolve().then(() => {
        const paragraph = element.shadowRoot.querySelector("p");
        expect(paragraph.textContent).toBe("The count is odd");
      });
    });

    it("should show even message for negative even numbers", () => {
      element.count = -2;

      return Promise.resolve().then(() => {
        const paragraph = element.shadowRoot.querySelector("p");
        expect(paragraph.textContent).toBe("The count is even");
      });
    });
  });

  describe("Getters", () => {
    it("should have correct displayCount getter", () => {
      element.count = 42;
      expect(element.displayCount).toBe("Count: 42");
    });

    it("should have correct isEven getter for even numbers", () => {
      element.count = 10;
      expect(element.isEven).toBe(true);
    });

    it("should have correct isEven getter for odd numbers", () => {
      element.count = 11;
      expect(element.isEven).toBe(false);
    });
  });
});
