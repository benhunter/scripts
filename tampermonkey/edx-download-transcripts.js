// ==UserScript==
// @name         Download Transcripts
// @namespace    https://www.github.com/benhunter/scripts/tampermonkey
// @version      2024-05-03
// @description  Download video transcripts from edX.
// @author       Ben
// @match        https://courses.edx.org/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        none
// @require http://code.jquery.com/jquery-latest.js
// @require https://cdn.jsdelivr.net/gh/CoeJoder/waitForKeyElements.js@v1.2/waitForKeyElements.js

// ==/UserScript==

function handleClick() {
    var sm = $('.subtitles-menu');
    const title = $("h3.hd").text();
    const filename = `${title}.txt`;
    download(filename, sm.text());
}

function addFeatures() {
  $('body').append('<input type="button" value="Download Transcript" id="dltranscript">');
  $("#dltranscript").css("position", "fixed").css("top", 0).css("left", 0);
  $('#dltranscript').click(handleClick);
}

function download(filename, text) {
  var element = document.createElement('a');
  element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
  element.setAttribute('download', filename);

  element.style.display = 'none';
  document.body.appendChild(element);

  element.click();

  document.body.removeChild(element);
}

// Just a backup in case the reference repo goes down.
function waitForKeyElements_(selectorOrFunction, callback, waitOnce, interval, maxIntervals) {
    console.log("debug looking for "); // + selectorOrFunction);
    if (typeof waitOnce === "undefined") {
        waitOnce = true;
    }
    if (typeof interval === "undefined") {
        interval = 300;
    }
    if (typeof maxIntervals === "undefined") {
        maxIntervals = -1;
    }
    if (typeof waitForKeyElements.namespace === "undefined") {
        waitForKeyElements.namespace = Date.now().toString();
    }
    var targetNodes = (typeof selectorOrFunction === "function")
            ? selectorOrFunction()
            : document.querySelectorAll(selectorOrFunction);

    var targetsFound = targetNodes && targetNodes.length > 0;
    if (targetsFound) {
        console.log("found something");
        targetNodes.forEach(function(targetNode) {
            var attrAlreadyFound = `data-userscript-${waitForKeyElements.namespace}-alreadyFound`;
            var alreadyFound = targetNode.getAttribute(attrAlreadyFound) || false;
            if (!alreadyFound) {
                console.log("callback");
                var cancelFound = callback(targetNode);
                if (cancelFound) {
                    targetsFound = false;
                }
                else {
                    targetNode.setAttribute(attrAlreadyFound, true);
                }
            }
        });
    }

    if (maxIntervals !== 0 && !(targetsFound && waitOnce)) {
        maxIntervals -= 1;
        setTimeout(function() {
            waitForKeyElements(selectorOrFunction, callback, waitOnce, interval, maxIntervals);
        }, interval);
    }
}

'use strict';
waitForKeyElements (".subtitles", addFeatures);
