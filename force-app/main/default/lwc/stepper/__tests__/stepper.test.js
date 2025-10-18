import { createElement } from "@lwc/engine-dom";
import Stepper from "c/stepper";

describe("c-stepper", () => {
  afterEach(() => {
    // Clean up the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders with step 1 active by default", () => {
    const element = createElement("c-stepper", {
      is: Stepper
    });
    document.body.appendChild(element);

    const steps = element.shadowRoot.querySelectorAll(".steps > div");
    expect(steps.length).toBe(5);

    // First step should be active
    expect(steps[0].className).toBe("step active");
    // The rest should be inactive
    expect(steps[1].className).toBe("step");
    expect(steps[2].className).toBe("step");
    expect(steps[3].className).toBe("step");
    expect(steps[4].className).toBe("step");
  });

  it("updates classes when currentStep changes", async () => {
    const element = createElement("c-stepper", {
      is: Stepper
    });
    document.body.appendChild(element);

    // Set currentStep to 3
    element.currentStep = 3;
    // Wait for re-render
    await Promise.resolve();

    const steps = element.shadowRoot.querySelectorAll(".steps > div");
    // Steps 1 and 2 should be marked completed
    expect(steps[0].className).toBe("step completed");
    expect(steps[1].className).toBe("step completed");
    // Step 3 should be active
    expect(steps[2].className).toBe("step active");
    // Steps 4 and 5 should be inactive
    expect(steps[3].className).toBe("step");
    expect(steps[4].className).toBe("step");
  });
});