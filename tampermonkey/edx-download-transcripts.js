// ==UserScript==
// @name         Download Transcripts
// @namespace    https://www.github.com/benhunter/scripts/tampermonkey
// @version      2026-06-08
// @description  Download video transcripts from edX.
// @author       Ben
// @match        https://courses.edx.org/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        none
// ==/UserScript==

(() => {
  'use strict';

  const BUTTON_ID = 'dltranscript';

  function safeFilename(value) {
    const cleaned = value.replace(/[<>:"/\\|?*\u0000-\u001f]/g, '_').trim();
    return `${cleaned || 'transcript'}.txt`;
  }

  function download(filename, text) {
    const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const element = document.createElement('a');
    element.href = url;
    element.download = filename;
    element.hidden = true;
    document.body.appendChild(element);
    element.click();
    element.remove();
    URL.revokeObjectURL(url);
  }

  function handleClick() {
    const subtitles = document.querySelector('.subtitles-menu');
    if (!subtitles) {
      return;
    }
    const title = document.querySelector('h3.hd')?.textContent || 'transcript';
    download(safeFilename(title), subtitles.textContent || '');
  }

  function addFeatures() {
    if (document.getElementById(BUTTON_ID) || !document.querySelector('.subtitles')) {
      return;
    }
    const button = document.createElement('button');
    button.id = BUTTON_ID;
    button.type = 'button';
    button.textContent = 'Download Transcript';
    Object.assign(button.style, {
      position: 'fixed',
      top: '0',
      left: '0',
      zIndex: '2147483647'
    });
    button.addEventListener('click', handleClick);
    document.body.appendChild(button);
  }

  addFeatures();
  new MutationObserver(addFeatures).observe(document.documentElement, {
    childList: true,
    subtree: true
  });
})();
