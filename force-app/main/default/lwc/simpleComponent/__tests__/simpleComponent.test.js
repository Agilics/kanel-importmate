import { createElement } from "@lwc/engine-dom";
import SimpleComponent from "c/simpleComponent";

describe("c-simple-component", () => {
  let element;

  beforeEach(() => {
    element = createElement("c-simple-component", {
      is: SimpleComponent
    });
    document.body.appendChild(element);
  });

  afterEach(() => {
    document.body.removeChild(element);
  });

  it("should display the default message", () => {
    const paragraph = element.shadowRoot.querySelector("p");
    expect(paragraph.textContent).toBe("Hello World");
  });

  it("should return correct greeting from getGreeting method", () => {
    const greeting = SimpleComponent.getGreeting("John");
    expect(greeting).toBe("Hello John!");
  });

  it("should return greeting with empty string", () => {
    const greeting = SimpleComponent.getGreeting("");
    expect(greeting).toBe("Hello !");
  });
});
