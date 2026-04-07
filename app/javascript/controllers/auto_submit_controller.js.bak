import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  submit() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.closest("form").requestSubmit()
    }, 300)
  }
}
