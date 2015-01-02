if (typeof XMLHttpRequest == "undefined") {
	window.XMLHttpRequest = function () {
		try { return new ActiveXObject("Msxml2.XMLHTTP.6.0"); }
		catch (e) {}
		try { return new ActiveXObject("Msxml2.XMLHTTP.3.0"); }
		catch (e) {}
		try { return new ActiveXObject("Msxml2.XMLHTTP"); }
		catch (e) {}
		throw new Error("No XMLHttpRequest.");
	};
}

function _(node, tagName, namespace, defaultValue) {
	try {
		return node.getElementsByTagName(tagName)[0].firstChild.nodeValue;
	}
	catch (e) {
		try {
			return node.getElementsByTagName(tagName)[0].firstChild.nodeValue;
		}
		catch (e) {
			return defaultValue || "";
		}
	}
}

document.addEventListener('DOMContentLoaded', function () {
	var xhr = new XMLHttpRequest();
	xhr.open("GET", "/pinboard.xml", true);
	xhr.onreadystatechange = function () {
		if (4 != xhr.readyState) { return; }

		// Stop with the spinning.
		var section = document.getElementById("links");
		var h1 = section.getElementsByTagName("h1")[0];
		h1.removeChild(h1.getElementsByTagName("img")[0]);

		var items = xhr.responseXML.getElementsByTagName("item");
		var ii = items.length;
		for (var i = 0; i < ii; ++i) {
			var item = items[i];
			var article = document.createElement("article");
			article.setAttribute("id", _(item, "date", "dc"));

			// Date and linked title.
			var header = document.createElement("header");
			var time = document.createElement("time");
			time.setAttribute("datetime", _(item, "date", "dc"));
			time.appendChild(document.createTextNode(
				_(item, "date", "dc").replace(/T.*$/, "")));
			header.appendChild(time);
			var h1 = document.createElement("h1");
			var a = document.createElement("a");
			a.setAttribute("href", _(item, "link"));
			a.appendChild(document.createTextNode(
				_(item, "title", undefined, "(untitled)")));
			h1.appendChild(a);
			header.appendChild(h1);
			article.appendChild(header);

			// Note text and permalink.
			var para = _(item, "description").split("\n\n");
			var jj = para.length - 1;
			for (var j = 0; j <= jj; ++j) {
				para[j] = para[j].replace(/  /, "\u00a0 ");
				var p = document.createElement("p");
				if (j == jj) {
					if (para[j].length) {
						p.appendChild(document.createTextNode(
							para[j] + "\u00a0 "));
					}
					var a = document.createElement("a");
					a.setAttribute("href", "#" + _(item, "date", "dc"));
					a.appendChild(document.createTextNode("#"));
					p.appendChild(a);
				}
				else if (para[j].length) {
					p.appendChild(document.createTextNode(para[j]));
				}
				article.appendChild(p);
			}

			section.appendChild(article);
		}

		// Link to pinboard.in/u:rcrowley.
		var p = document.createElement("p");
		p.appendChild(document.createTextNode("More at "));
		var a = document.createElement("a");
		a.setAttribute("href", "http://pinboard.in/u:rcrowley");
		a.appendChild(document.createTextNode("pinboard.in/u:rcrowley"));
		p.appendChild(a);
		p.appendChild(document.createTextNode("."));
		section.appendChild(p);

	}
	xhr.send(null);
}, false);
