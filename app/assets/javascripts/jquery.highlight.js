/*
 * jQuery Highlight plugin
 *
 * Based on highlight v3 by Johann Burkard
 * http://johannburkard.de/blog/programming/javascript/highlight-javascript-text-higlighting-jquery-plugin.html
 *
 * Copyright (c) 2009 Bartek Szopka
 * Licensed under MIT license.
 */

!function(t){"function"==typeof define&&define.amd?define(["jquery"],t):t("object"==typeof exports?require("jquery"):jQuery)}(function(t){t.extend({highlight:function(n,r,e,o){if(3===n.nodeType){var s=n.data.match(r);if(s){var i=document.createElement(e||"span");i.className=o||"highlight";var a=n.data.indexOf(s[1],s.index),l=n.splitText(a);l.splitText(s[1].length);var c=l.cloneNode(!0);return i.appendChild(c),l.parentNode.replaceChild(i,l),1}}else if(1===n.nodeType&&n.childNodes&&!/(script|style)/i.test(n.tagName)&&(n.tagName!==e.toUpperCase()||n.className!==o))for(var u=0;u<n.childNodes.length;u++)u+=t.highlight(n.childNodes[u],r,e,o);return 0}}),t.fn.unhighlight=function(n){var r={className:"highlight",element:"span"};return t.extend(r,n),this.find(r.element+"."+r.className).each(function(){var t=this.parentNode;t.replaceChild(this.firstChild,this),t.normalize()}).end()},t.fn.highlight=function(n,r){var e={className:"highlight",element:"span",caseSensitive:!1,wordsOnly:!1,wordsBoundary:"\\b"};if(t.extend(e,r),"string"==typeof n&&(n=[n]),n=t.grep(n,function(t){return""!=t}),n=t.map(n,function(t){return t.replace(/[-[\]{}()*+?.,\\^$|#\s]/g,"\\$&")}),0===n.length)return this;var o=e.caseSensitive?"":"i",s="("+n.join("|")+")";e.wordsOnly&&(s=(e.wordsBoundaryStart||e.wordsBoundary)+s+(e.wordsBoundaryEnd||e.wordsBoundary));var i=RegExp(s,o);return this.each(function(){t.highlight(this,i,e.element,e.className)})}});
