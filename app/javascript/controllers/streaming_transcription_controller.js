import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["button", "buttonText", "transcript", "partialText", "error", "liveIndicator", "micIcon", "recordingDot"]
  static values = { sessionToken: String }

  connect() {
    this.isListening = false
    this.mediaRecorder = null
    this.subscription = null
    this.audioContext = null
  }

  async toggle() {
    if (this.isListening) {
      this.stopListening()
    } else {
      await this.startListening()
    }
  }

  async startListening() {
    try {
      this.hideError()

      // Get microphone access
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 16000
        }
      })

      // Subscribe to Action Cable channel
      this.subscription = consumer.subscriptions.create(
        { channel: "TranscriptionChannel", session_token: this.sessionTokenValue },
        {
          received: (data) => this.handleMessage(data),
          connected: () => {
            console.log("[Transcription] Connected to channel")
            this.setupAudioProcessing(stream)
          },
          disconnected: () => {
            console.log("[Transcription] Disconnected from channel")
            this.handleDisconnect()
          },
          rejected: () => {
            console.error("[Transcription] Connection rejected")
            this.showError("Connection rejected")
            this.stopListening()
          }
        }
      )

      this.isListening = true
      this.updateUI()

    } catch (error) {
      console.error("[Transcription] Microphone error:", error)
      this.showError("Could not access microphone. Please allow microphone permissions.")
    }
  }

  setupAudioProcessing(stream) {
    // Use AudioWorklet for better performance, fallback to ScriptProcessor
    this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: 16000
    })

    const source = this.audioContext.createMediaStreamSource(stream)

    // Use ScriptProcessor for simplicity (AudioWorklet would be better for production)
    const processor = this.audioContext.createScriptProcessor(4096, 1, 1)

    processor.onaudioprocess = (e) => {
      if (!this.isListening || !this.subscription) return

      const inputData = e.inputBuffer.getChannelData(0)

      // Convert float32 to int16 PCM
      const pcmData = this.float32ToInt16(inputData)

      // Base64 encode and send
      const base64 = this.arrayBufferToBase64(pcmData.buffer)
      this.subscription.send({ audio: base64 })
    }

    source.connect(processor)
    processor.connect(this.audioContext.destination)

    this.stream = stream
    this.processor = processor
    this.source = source
  }

  float32ToInt16(float32Array) {
    const int16Array = new Int16Array(float32Array.length)
    for (let i = 0; i < float32Array.length; i++) {
      const s = Math.max(-1, Math.min(1, float32Array[i]))
      int16Array[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
    }
    return int16Array
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ''
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return btoa(binary)
  }

  handleMessage(data) {
    switch (data.type) {
      case "partial":
        this.showPartialTranscript(data.text)
        break

      case "final":
        this.appendFinalTranscript(data.text)
        break

      case "error":
        this.showError(data.message)
        break
    }
  }

  showPartialTranscript(text) {
    if (this.hasPartialTextTarget) {
      this.partialTextTarget.textContent = text
      this.partialTextTarget.classList.remove("hidden")
    }
  }

  appendFinalTranscript(text) {
    // Hide partial
    if (this.hasPartialTextTarget) {
      this.partialTextTarget.classList.add("hidden")
      this.partialTextTarget.textContent = ""
    }

    // Append final
    if (this.hasTranscriptTarget) {
      const span = document.createElement("span")
      span.textContent = text + " "
      span.classList.add("animate-fade-up")
      this.transcriptTarget.appendChild(span)

      // Keep only last ~500 chars visible
      while (this.transcriptTarget.textContent.length > 500 && this.transcriptTarget.firstChild) {
        this.transcriptTarget.removeChild(this.transcriptTarget.firstChild)
      }

      // Auto-scroll
      this.transcriptTarget.scrollLeft = this.transcriptTarget.scrollWidth
    }
  }

  stopListening() {
    // Stop audio processing
    if (this.processor) {
      this.processor.disconnect()
      this.processor = null
    }
    if (this.source) {
      this.source.disconnect()
      this.source = null
    }
    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }

    // Unsubscribe from channel
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }

    this.isListening = false
    this.updateUI()
  }

  updateUI() {
    if (this.hasButtonTarget) {
      if (this.isListening) {
        this.buttonTarget.classList.add("btn-listening")
      } else {
        this.buttonTarget.classList.remove("btn-listening")
      }
    }

    if (this.hasButtonTextTarget) {
      this.buttonTextTarget.textContent = this.isListening ? "Stop" : "Start Listening"
    }

    // Toggle mic icon / recording dot
    if (this.hasMicIconTarget) {
      this.micIconTarget.classList.toggle("hidden", this.isListening)
    }
    if (this.hasRecordingDotTarget) {
      this.recordingDotTarget.classList.toggle("hidden", !this.isListening)
    }

    if (this.hasLiveIndicatorTarget) {
      this.liveIndicatorTarget.classList.toggle("hidden", !this.isListening)
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("hidden")
    }
  }

  handleDisconnect() {
    if (this.isListening) {
      this.stopListening()
    }
  }

  disconnect() {
    this.stopListening()
  }
}
