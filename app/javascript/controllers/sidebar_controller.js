import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sidebar", "overlay" ]

  open() {
    document.body.classList.add("sidebar-open")
    this.overlayTarget.classList.remove("hidden")
  }

  close() {
    document.body.classList.remove("sidebar-open")
    this.overlayTarget.classList.add("hidden")
  }

  toggle() {
    if (document.body.classList.contains("sidebar-open")) {
      this.close()
    } else {
      this.open()
    }
  }

  closeOnOverlayClick() {
    this.close()
  }
}
