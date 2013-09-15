function delicious(raw) {

	// Fuck you for saying this is insecure, I trust del.icio.us
	var obj = eval(raw);

	var ol = document.createElement('ol');
	ol.className = 'delicious comments';
	for (var i = obj.length - 1; i >= 0; --i) {
		console.log(obj[i].a + ': ' + obj[i].n);
		var li = document.createElement('li');

		// Note text
		var para = obj[i].n.split('\n\n');
		var jj = para.length;
		for (var j = 0; j < jj; ++j) {
			var p = document.createElement('p');
			p.appendChild(document.createTextNode(para[j]));
			li.appendChild(p);
		}

		// Byline
		var a = document.createElement('a');
		a.setAttribute('href', 'http://delicious.com/' + obj[i].a);
		a.appendChild(document.createTextNode(obj[i].a));
		var p = document.createElement('p');
		if (obj[i].n.length) {
			p.appendChild(document.createTextNode('\u2014 '));
		}
		p.appendChild(a);
		p.appendChild(document.createTextNode(' \u2014 ' + obj[i].dt));
		li.appendChild(p);

		ol.appendChild(li);
	}

	// Heading and into the document it goes
	var a = document.createElement('a');
	a.setAttribute('href', 'http://delicious.com/save?v=4;url=' +
		encodeURIComponent(window.location) + ';title=' +
		encodeURIComponent(document.title));
	a.appendChild(document.createTextNode('Bookmark \u2192'));
	var small = document.createElement('small');
	small.appendChild(a);
	var h1 = document.createElement('h1');
	h1.appendChild(document.createTextNode('del.icio.us '));
	h1.appendChild(small);
	var div = document.getElementById('content');
	div.appendChild(h1);
	div.appendChild(ol);

}
