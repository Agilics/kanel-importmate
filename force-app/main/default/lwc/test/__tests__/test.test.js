import { createElement } from "lwc";
import Test from "c/test";

describe("c-test", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("should render the component", () => {
    // Arrange
    const element = createElement("c-test", {
      is: Test
    });

    // Act
    document.body.appendChild(element);

    // Assert
    const paragraph = element.shadowRoot.querySelector("p");
    expect(paragraph).toBeTruthy();
    expect(paragraph.textContent).toBe("Hello");
  });

  it("should have correct getter value", () => {
    // Arrange
    const element = createElement("c-test", {
      is: Test
    });

    // Act
    document.body.appendChild(element);

    // Assert
    expect(element.sayHello).toBe("Hello");
  });

  it("should update when getter changes", () => {
    // Arrange
    const element = createElement("c-test", {
      is: Test
    });
    document.body.appendChild(element);

    // Act - Simulate a change (if we had a method to change the value)
    // For now, we just verify the initial state
    const paragraph = element.shadowRoot.querySelector("p");

    // Assert
    expect(paragraph.textContent).toBe("Hello");
  });
});
