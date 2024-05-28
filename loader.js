"use strict";

/**
 * MyAudioManagerChannel
 * 
 * A simple class that represents an oscillator channel.
 * 
 * @property {OscillatorNode} oscillator
 * @property {GainNode} gain
 */
class MyAudioManagerChannel {
    constructor(audioContext, destination) {
        this.context = audioContext;
        this.destination = destination;
        this.oscillator = null;
        this.gain = null;
        this.type = 0;
    }

    /**
     * Sets the type of the oscillator.
     * 
     * @param {0 | 1 | 2 | 3} type - The type of the oscillator.
     */
    setType(type) {
        this.type = type;
    }

    reset() {
        if (this.oscillator) {
            this.oscillator = null;
            this.gain.disconnect();
            this.gain = null;
        }
        this.oscillator = this.context.createOscillator();
        const types = ['sine', 'square', 'sawtooth', 'triangle'];
        this.oscillator.type = types[this.type];
        this.gain = this.context.createGain();
        this.oscillator.connect(this.gain);
        this.gain.connect(this.destination);
    }

    /**
     * Plays a chirp on the channel.
     * 
     * @param {number} start_frequency
     * @param {number} end_frequency
     * @param {number} duration 
     */
    playChirp(start_frequency, end_frequency, duration) {
        this.reset();
        const currentTime = this.context.currentTime;
        this.oscillator.frequency.setValueAtTime(start_frequency, currentTime);
        this.oscillator.frequency.exponentialRampToValueAtTime(end_frequency, currentTime + duration);
        this.gain.gain.setValueAtTime(1, currentTime);
        this.gain.gain.exponentialRampToValueAtTime(0.0001, currentTime + duration);
        this.oscillator.start();
        this.oscillator.stop(currentTime + duration);
    }

    /**
     * Plays a constant tone on the channel.
     * 
     * @param {number} frequency
     */
    play(frequency) {
        this.reset();
        this.oscillator.frequency.value = frequency;
        this.gain.gain.value = 1;
        this.oscillator.start();
    }
}

/**
 * MyAudioManager
 * 
 * A simple class that manages a number of oscillator channels.
 * Each channel can be played with a given frequency, duration, and exponential fade.
 * A global volume can be set to scale all channels.
 * 
 * @property {AudioContext} audioContext - The audio context.
 * @property {GainNode} volumeNode - The volume node.
 * @property {Array<MyAudioManagerChannel>} audioChannels - The audio channels.
 */
class MyAudioManager {
    constructor() {
        this.audioContext = new AudioContext();
        this.volumeNode = this.audioContext.createGain();
        this.volumeNode.connect(this.audioContext.destination);
        this.audioChannels = [];
    }

    /**
     * Sets the global volume.
     * 
     * @param {number} volume - The volume to set.
     */
    setVolume(volume) {
        this.volumeNode.gain.value = volume;
    }

    /**
     * Sets the number of channels.
     * 
     * @param {number} count - The number of channels to set.
     */
    setChannelCount(count) {
        while (this.audioChannels.length < count) {
            const new_channel = new MyAudioManagerChannel(this.audioContext, this.volumeNode);
            this.audioChannels.push(new_channel);
        }
        while (this.audioChannels.length > count) {
            this.audioChannels.pop();
        }
    }

    /**
     * Sets the type of the oscillator on the given channel.
     * 
     * @param {number} channel - The channel to set.
     * @param {0 | 1 | 2 | 3} type - The type of the oscillator.
     */
    setChannelType(channel, type) {
        this.audioChannels[channel].setType(type);
    }

    /**
     * Plays a chirp on the given channel.
     * 
     * @param {number} channel - The channel to play on.
     * @param {number} start_frequency - The start frequency of the chirp.
     * @param {number} end_frequency - The end frequency of the chirp.
     * @param {number} duration - The duration of the chirp.
     */
    playFrequencyChirp(channel, start_frequency, end_frequency, duration) {
        this.audioChannels[channel].playChirp(start_frequency, end_frequency, duration);
    }

    /**
     * Plays a constant tone on the given channel.
     * 
     * @param {number} channel - The channel to play on.
     * @param {number} frequency - The frequency of the tone.
     */
    playFrequencyTone(channel, frequency) {
        this.audioChannels[channel].play(frequency);
    }

    /**
     * Halts the audio context.
     */
    halt() {
        this.audioContext.suspend();
    }

    /**
     * Runs the audio context.
     */
    run() {
        this.audioContext.resume();
    }
}

/**
 * MyWASMCanvasLoader
 * 
 * A simple class to load a WebAssembly module to interact with a canvas ala
 * a native application given a window.
 * 
 * @property {HTMLCanvasElement} canvas - The canvas to draw on.
 * @property {CanvasRenderingContext2D} ctx - The canvas context.
 * @property {WebAssembly.Instance} wasmModuleInstance - The loaded WebAssembly instance.
 * @property {number} debugLineHeight - The height of a debug line in pixels.
 * @property {number} debugConsoleLine - The current line in the debug console.
 * @property {number} targetFrameRate - The target frame rate (set by the application). Default is 30.
 * @property {boolean} appShouldRun - Whether the application should run or has been halted.
 * @property {boolean} appInitialized - Whether the application has been initialized.
 * @property {Array<[string,Function]>} eventListeners - The event listeners attached to the canvas (for cleanup).
 * @property {MyAudioManager?} audioManager - The audio manager.
 */
class MyWASMCanvasLoader {
    /**
     * @param {HTMLCanvasElement} canvas  
     * @param {Console?} debugConsole
     */
    constructor(canvas, debugConsole) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.wasmModuleInstance = null;
        this.initDebug(debugConsole);
        this.appTargetFPS = 30;
        this.appShouldRun = false;
        this.appInitialized = false;
        this.eventListeners = [];
        this.audioManager = null;
        try {
            this.audioManager = new MyAudioManager();
        } catch (e) {
            this.debugError('WebAudio not started: ' + e);
        }
    }

    /* ICKY WEBASSEMBLY INTERNALS */

    /**
     * Decodes a string from a Zig pointer and length.
     *
     * @param {number} pointer - The pointer to the string.
     * @param {number} length - The length of the string.
     * @returns {string} - The decoded string.
     * @see https://blog.battlefy.com/zig-made-it-easy-to-pass-strings-back-and-forth-with-webassembly
     */
    decodeString(pointer, length) {
        const slice = new Uint8Array(this.wasmModuleInstance.exports.memory.buffer, pointer, length);
        return new TextDecoder().decode(slice);
    }

    /* JAVASCRIPT INTERFACE */

    /**
     * Loads the WebAssembly module from the given URL.
     * 
     * @param {string | Uint8Array | Response} moduleLoad - The URL of the WebAssembly module to fetch OR the bytes of the WebAssembly module.
     * @returns {Promise<void>}
     */
    async load(moduleLoad) {
        const imports = {
            env: {
                // Debug interface
                debugMessage: this.debugAppMessage.bind(this),
                debugError: this.debugAppError.bind(this),
                // Rendering interface
                setWindowTitle: this.appSetTitle.bind(this),
                setTargetFPS: this.setTargetFPS.bind(this),
                halt: this.halt.bind(this),
                // Drawing interface
                clear: this.clear.bind(this),
                setFillColor: this.setFillColor.bind(this),
                setAlpha: this.setAlpha.bind(this),
                setStrokeColor: this.setStrokeColor.bind(this),
                drawRect: this.drawRect.bind(this),
                drawCircle: this.drawCircle.bind(this),
                drawLine: this.drawLine.bind(this),
                drawText: this.appDrawText.bind(this),
            }
        }

        if (this.audioManager) {
            imports.env['setAudioChannelCount'] = this.audioManager.setChannelCount.bind(this.audioManager);
            imports.env['setAudioChannelType'] = this.audioManager.setChannelType.bind(this.audioManager);
            imports.env['playFrequencyChirp'] = this.audioManager.playFrequencyChirp.bind(this.audioManager);
            imports.env['playFrequencyTone'] = this.audioManager.playFrequencyTone.bind(this.audioManager);
        } else {
            // Dummy audio functions
            imports.env['setAudioChannelCount'] = () => { };
            imports.env['setAudioChannelType'] = () => { };
            imports.env['playFrequencyChirp'] = () => { };
            imports.env['playFrequencyTone'] = () => { };
        }

        const expected_exports = ['init', 'draw'];

        try {
            let response = null;
            let len = 0;
            if (moduleLoad instanceof Response) {
                response = moduleLoad;
                len = +response.headers.get('Content-Length');
            } else if (moduleLoad instanceof Uint8Array) {
                response = new Response(moduleLoad);
                response.headers.set('Content-Type', 'application/wasm');
                response.headers.set('Content-Length', moduleLoad.length.toString());
                len = moduleLoad.length;
            } else {
                this.debugMessage('Starting download...');
                response = await fetch(moduleLoad);
                len = +response.headers.get('Content-Length');
            }
            this.clear();
            this.debugMessage('Loading and compiling...');
            const { instance } = await WebAssembly.instantiateStreaming(response, imports);
            this.wasmModuleInstance = instance;
            for (const exportName of expected_exports) {
                if (!this.wasmModuleInstance.exports[exportName]) {
                    throw new Error(`Missing export: ${exportName}`);
                }
            }
            this.initEventListeners();
            this.clear();
            this.debugMessage(`Module size: ${len} bytes`);
            this.debugMessage('Loaded and compiled!');
            this.drawStartButton(false);
        }
        catch (e) {
            this.debugError('Error: ' + e);
            // Re-throw the error so the caller can handle it.
            throw e;
        }
    }

    /**
     * A simple start button.
     * 
     * @param {boolean} highlight 
     * @returns 
     */
    drawStartButton(highlight) {
        const buttonHeight = 60;
        const buttonPadding = 10;
        this.ctx.fillStyle = 'lightgray';
        this.ctx.fillRect(0, this.canvas.height - buttonHeight, this.canvas.width, buttonHeight);
        this.ctx.fillStyle = highlight ? 'lightgreen' : 'green';
        this.ctx.fillRect(buttonPadding, this.canvas.height - (buttonHeight - buttonPadding), this.canvas.width - 2 * buttonPadding, buttonHeight - 2 * buttonPadding);
        this.ctx.fillStyle = 'black';
        this.ctx.font = `${buttonHeight - 2 * buttonPadding}px monospace`;
        this.ctx.fillText('Start', this.canvas.width / 2 - buttonHeight, this.canvas.height - 1.5 * buttonPadding);
    }



    /**
     * Runs the WebAssembly game loop.
     * @returns {Promise<void>}
     */
    run() {
        if (this.wasmModuleInstance) {
            if (!this.appInitialized) {
                this.debugMessage('Starting...');
                try {
                    this.wasmModuleInstance.exports.init(this.canvas.width, this.canvas.height);
                    this.appInitialized = true;
                    this.appShouldRun = true;
                } catch (e) {
                    this.debugError('Error: ' + e);
                    return;
                }
            } else {
                this.appShouldRun = true;
            }
            this.debugMessage('Running...');
            requestAnimationFrame(this.frameCallback.bind(this));
        }
    }

    /**
     * Adds an event listener to the canvas.
     */
    addEventListener(event, listener) {
        this.canvas.addEventListener(event, listener);
        this.eventListeners.push([event, listener]);
    }

    /**
     * Initializes the event listeners.
     */
    initEventListeners() {
        this.addEventListener('mousedown', this.mousedown.bind(this));
        this.addEventListener('mouseup', this.mouseup.bind(this));
        this.addEventListener('mousemove', this.mousemove.bind(this));
        this.addEventListener('mouseleave', this.mouseleave.bind(this));
        if (this.wasmModuleInstance.exports.keydown) {
            this.addEventListener('keydown', this.keydown.bind(this));
        }
        if (this.wasmModuleInstance.exports.keyup) {
            this.addEventListener('keyup', this.keyup.bind(this));
        }
    }

    /**
     * Mouse down event listener.
     */
    mousedown(event) {
        if (!this.appShouldRun) {
            this.drawStartButton(false);
            this.run();
        } else if (this.wasmModuleInstance.exports.mousedown) {
            this.wasmModuleInstance.exports.mousedown(event.button);
        }
    }

    /**
     * Mouse up event listener.
     */
    mouseup(event) {
        if (!this.appShouldRun) {
            this.drawStartButton(true);
        } else if (this.wasmModuleInstance.exports.mouseup) {
            this.wasmModuleInstance.exports.mouseup(event.button);
        }
    }

    /**
     * Mouse move event listener.
     */
    mousemove(event) {
        if (!this.appShouldRun) {
            this.drawStartButton(true);
        } else if (this.wasmModuleInstance.exports.mousemove) {
            this.wasmModuleInstance.exports.mousemove(event.offsetX, event.offsetY);
        }
    }

    /**
     * Mouse out event listener.
     */
    mouseleave(event) {
        if (!this.appShouldRun) {
            this.drawStartButton(false);
        }
    }

    /**
     * Key down event listener.
     */
    keydown(event) {
        this.wasmModuleInstance.exports.keydown(event.key);
    }

    /**
     * Key up event listener.
     */
    keyup(event) {
        this.wasmModuleInstance.exports.keyup(event.key);
    }

    /**
     * Halts the application, removes event listeners, and nulls the WebAssembly instance.
     */
    destroy() {
        this.halt();
        for (const [event, listener] of this.eventListeners) {
            this.canvas.removeEventListener(event, listener);
        }
        this.wasmModuleInstance = null;
    }

    /**
     * The main game loop.
     * 
     * @param {*} event 
     */
    frameCallback(event) {
        if (!this.appShouldRun) {
            return;
        }
        requestAnimationFrame(this.frameCallback.bind(this));
        const deltaTimeMs = this.lastFrameTime ? event - this.lastFrameTime : 1000 / this.appTargetFPS;
        const deltaTimeSeconds = deltaTimeMs / 1000;
        let should_draw = this.lastFrameTime == undefined || deltaTimeSeconds >= 1 / this.appTargetFPS;
        if (should_draw) {
            this.lastFrameTime = event;
            try {
                this.wasmModuleInstance.exports.draw(deltaTimeSeconds);
            } catch (e) {
                this.debugError('Error: ' + e);
                this.halt();
            }
        }
    }

    /* DEBUG INTERFACE */

    /**
     * Initializes the debug console.
     * 
     * @param {Console?} debugConsole - The HTML console to use for debug messages.
     */
    initDebug(debugConsole) {
        this.debugLineHeight = 14;
        this.debugConsoleOnscreenLine = 1;
        this.debugConsole = debugConsole;
        this.debugMessage('Initializing...');
    }

    /**
     * Writes the given message to the screen, deubg console, and console.
     * 
     * @param {string} message - The message to display.
     */
    debugMessage(message) {
        console.log(this.constructor.name, message)
        if (this.debugConsole instanceof HTMLElement) {
            const pre = document.createElement('pre');
            pre.textContent = message;
            this.debugConsole.appendChild(pre);
        }
        this.ctx.font = `${this.debugLineHeight}px monospace`;
        this.ctx.fillStyle = 'blue';
        this.ctx.fillText(message, 0, this.debugLineHeight * (this.debugConsoleOnscreenLine++));
    }

    /**
     * Writes the given error message to the screen, debug console, and console.
     */
    debugError(message) {
        console.error(this.constructor.name, message)
        if (this.debugConsole instanceof HTMLElement) {
            const pre = document.createElement('pre');
            pre.textContent = message;
            pre.style.color = 'red';
            this.debugConsole.appendChild(pre);
        }
        this.ctx.font = `${this.debugLineHeight}px monospace`;
        this.ctx.fillStyle = 'red';
        this.ctx.fillText(message, 0, this.debugLineHeight * (this.debugConsoleOnscreenLine++));
    }

    /**
     * Given a pointer and length, reads a string from the WebAssembly memory and
     * writes it to the debug console.
     * 
     * @see debugMessage
     * @see decodeString
     */
    debugAppMessage(pointer, length) {
        this.debugMessage(this.decodeString(pointer, length));
    }

    /**
     * Given a pointer and length, reads a string from the WebAssembly memory and
     * writes it to the debug console as an error.
     * 
     * @see debugError
     * @see decodeString
     */
    debugAppError(pointer, length) {
        this.debugError(this.decodeString(pointer, length));
    }

    /* RENDERING INTERFACE */

    /**
     * Sets the window title.
     */
    setTitle(title) {
        document.title = title;
    }

    /**
     * Sets the window title from a pointer and length.
     * 
     * @param {number} pointer 
     * @param {number} length 
     * @see decodeString
     */
    appSetTitle(pointer, length) {
        this.setTitle(this.decodeString(pointer, length));
    }

    /**
     * Sets the target frame rate.
     */
    setTargetFPS(fps) {
        this.appTargetFPS = fps;
    }

    /**
     * Halt the application.
     */
    halt() {
        this.appShouldRun = false;
        this.debugMessage('Halted');
    }

    /* DRAWING INTERFACE */

    /**
     * Clears the canvas.
     */
    clear() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this.debugConsoleOnscreenLine = 1;
    }

    /**
     * Sets the fill color of the canvas.
     */
    setFillColor(r, g, b) {
        this.ctx.fillStyle = `rgb(${r},${g},${b})`;
    }

    /**
     * Sets the fill alpha of the canvas.
     */
    setAlpha(a) {
        this.ctx.globalAlpha = a;
    }

    /**
     * Sets the stroke color of the canvas.
     */
    setStrokeColor(r, g, b) {
        this.ctx.strokeStyle = `rgb(${r},${g},${b})`;
    }

    /**
     * Draws a rectangle on the canvas.
     */
    drawRect(x, y, width, height) {
        this.ctx.fillRect(x, y, width, height);
    }

    /**
     * Draws a circle on the canvas.
     */
    drawCircle(x, y, radius) {
        this.ctx.beginPath();
        this.ctx.arc(x, y, radius, 0, 2 * Math.PI);
        this.ctx.fill();
    }

    /**
     * Draws a line on the canvas.
     */
    drawLine(x1, y1, x2, y2, thickness) {
        this.ctx.lineWidth = thickness;
        this.ctx.beginPath();
        this.ctx.moveTo(x1, y1);
        this.ctx.lineTo(x2, y2);
        this.ctx.stroke();
    }

    /**
     * Draws a line of text on the canvas.
     * 
     * @param {string} text - The text to draw.
     * @param {number} x - The x-coordinate.
     * @param {number} y - The y-coordinate.
     */
    drawText(text, x, y) {
        this.ctx.fillText(text, x, y);
    }

    /**
     * Draws a line of text on the canvas from a pointer and length.
     * 
     * @param {number} x - The x-coordinate.
     * @param {number} y - The y-coordinate.
     * @param {number} pointer - The pointer to the text.
     * @param {number} length - The length of the text (in bytes).
     */
    appDrawText(x, y, pointer, length) {
        this.drawText(this.decodeString(pointer, length), x, y);
    }
}

if (!window.WebAssembly) {
    alert('WebAssembly is not supported in this browser');
    /**
     * DummyWASMCanvasLoader
     * 
     * A dummy class to present an error message when WebAssembly is not supported.
     * 
     * @property {HTMLCanvasElement} canvas - The canvas to draw on.
     * @property {CanvasRenderingContext2D} ctx - The canvas context.
     * @property {null} wasmModuleInstance - Always null.
     */
    MyWASMCanvasLoader = class {
        constructor(canvas) {
            this.canvas = canvas;
            this.ctx = canvas.getContext('2d');
            this.wasmModuleUrl = wasmModuleUrl;
            this.wasmModuleInstance = null;
            this.debugMessage('Unable to load WebAssembly');
        }

        run() {
            this.debugMessage('Unable to load WebAssembly');
        }
    };
}
if (!window.WebAssembly.instantiateStreaming) {
    WebAssembly.instantiateStreaming = (resp, importObject) => {
        return resp.then(response => {
            return response.arrayBuffer();
        }).then(bytes => {
            return WebAssembly.instantiate(bytes, importObject);
        });
    };
}
