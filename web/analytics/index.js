var directadvert_horizonatal='(function(e){var js=document.getElementById("148142811766854"); var block=document.createElement("div"); block.id=parseInt(Math.random()*1e9).toString(16)+e; js.parentNode.insertBefore(block,js); if("undefined"===typeof window.loaded_blocks_directadvert){window.loaded_blocks_directadvert=[]; function n(){var e=window.loaded_blocks_directadvert.shift(); var t=e.adp_id; var r=e.div; var i=document.createElement("script"); i.async=true; i.charset="windows-1251"; var as=(typeof __da_already_shown!="undefined")?"&as="+__da_already_shown.slice(-20).join(":"):""; i.src="https://code.directadvert.ru/data/"+t+".js?async=1&div="+r+"&t="+Math.random()+as; var s=document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0]; var o; s.appendChild(i); i.onload=function(){o=setInterval(function(){if(document.getElementById(r).innerHTML && window.loaded_blocks_directadvert.length){n(); clearInterval(o)}},50)}; i.onerror=function(){o=setInterval(function(){if(window.loaded_blocks_directadvert.length){n(); clearInterval(o)}},50)}; } setTimeout(n)}window.loaded_blocks_directadvert.push({adp_id: e,div: block.id})})(66854)';
var directadvert_horizonal_id='148142811766854';

var directadvert_vertical='(function(e){var js=document.getElementById("4654527579235582"); var block=document.createElement("div"); block.id=parseInt(Math.random()*1e9).toString(16)+e; js.parentNode.insertBefore(block,js); if("undefined"===typeof window.loaded_blocks_directadvert){window.loaded_blocks_directadvert=[]; function n(){var e=window.loaded_blocks_directadvert.shift(); var t=e.adp_id; var r=e.div; var i=document.createElement("script"); i.async=true; i.charset="windows-1251"; var as=(typeof __da_already_shown!="undefined")?"&as="+__da_already_shown.slice(-20).join(":"):""; i.src="https://code.directadvert.ru/data/"+t+".js?async=1&div="+r+"&t="+Math.random()+as; var s=document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0]; var o; s.appendChild(i); i.onload=function(){o=setInterval(function(){if(document.getElementById(r).innerHTML && window.loaded_blocks_directadvert.length){n(); clearInterval(o)}},50)}; i.onerror=function(){o=setInterval(function(){if(window.loaded_blocks_directadvert.length){n(); clearInterval(o)}},50)}; } setTimeout(n)}window.loaded_blocks_directadvert.push({adp_id: e,div: block.id})})(9235582)';
var directadvert_vertical_id='4654527579235582';

var yandexRTBDivsModified = {};

function devex(regex){
    var all_divs = document.getElementsByTagName('div');
    var divs = [];

    for (var i = 0; i < all_divs.length; i++) {
        var div = all_divs[i];

        if (div.className.match(regex)) {
            divs.push(div);
        }
    }
    return divs
}

function idex(ids){
    var result = document.querySelectorAll(ids);
    return Array.from(result);
}

function findDivByClassRegex() {
    var arrayOfArrays = [];

    arrayOfArrays.push(idex('div[id^="yandex_rtb"]'));
    arrayOfArrays.push(devex(/advert-vertical-block-container/))
    arrayOfArrays.push(devex('/ya-container/'));
    arrayOfArrays.push(devex(/^(?:[a-zA-Z0-9]{9}\s){2}[a-zA-Z0-9]{9}$/))
   
    return [].concat(...arrayOfArrays);
}

function findAndModifyYandexRTBDivs() {
    var divs = findDivByClassRegex();
    divs.forEach(function(div) {
        if (!yandexRTBDivsModified[div.id]) {
            yandexRTBDivsModified[div.id] = true;
            
            var content;
            var id;
            if (div.offsetWidth >= div.offsetHeight) {
                content = directadvert_horizonatal;
                id = directadvert_horizonal_id;
            } else {
                content = directadvert_vertical;
                id = directadvert_vertical_id;
            }

          //  console.log('FOUND: ' + div.id);

            div.innerHTML = ""; 
            div.id=id;
            div.style.width = '100%';
            div.style.height = '100%';

            var scriptElm = document.createElement('script');
            scriptElm.setAttribute('class', 'class-name');
            var inlineCode = document.createTextNode(content);
            scriptElm.appendChild(inlineCode); 
            document.body.appendChild(scriptElm);
        }
    });
}


function observeDOMChanges() {
    var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
                findAndModifyYandexRTBDivs();
        });
    });
    var config = { childList: true, subtree: true };
    observer.observe(document.body, config);
}

document.addEventListener('DOMContentLoaded', function() {
    findAndModifyYandexRTBDivs();
    observeDOMChanges();
});

window.addEventListener('load', function() {
    findAndModifyYandexRTBDivs();
    observeDOMChanges();
});

 setInterval(function() {
    findAndModifyYandexRTBDivs();
}, 500);