var positions = [
	[
		[42.104942, -87.739238], // 931 Oak Street, Winnetka, IL
		[37.649714992776545, -84.7805685131092], // 833 West Lexington, Danville, KY
		[38.643379747536315, -90.3129786579151], // Hurd Hall
		[38.64794236789905, -90.30487704558561], // Brookings Hall
		[38.6164718, -90.26865049999998], // 4945 Daggett Ave, St Louis, MO
		[37.7987790824317, -122.42115426345059], // 2265 Larkin Street, San Francisco, CA
		[43.53116716018008, 5.4555718274574305] // Parc Rambot, Aix-en-Provence, France
	],
	[
		[37.776301120614875, -122.43468416464424], // Alamo Square
		[37.791101762788934, -122.43762923014259], // Alta Plaza
        // [37.861844, -122.422071] // Angel Island
		[37.798019866103076, -122.42039067280388], // Amarena
		[37.77836389143005, -122.38985104096031], // AT&T Park
		[37.776343521416834, -122.42651415598488], // Bar Jules
		[37.79686053552504, -122.40287718904113], // Bix
		[37.806103942565265, -122.42058915627098], // Blazing Saddles
		[37.79715407889672, -122.42216897738075], // Bullitt
		[37.775635424843436, -122.40947676432228], // City Beer Store
        // [37.765168, -122.438429] // Corona Heights
        // [37.805999, -122.450244] // Crissy Field
		[37.880058237851735, -122.52318767440414], // Dipsea
		[37.7954065778494, -122.3935417605648], // Ferry Building
        // [37.810547, -122.476554] // Fort Point
		[37.79842361407403, -122.41902811062431], // Frascati
		[37.74386374575801, -122.42201206815338], // Front Porch
        // [37.768611, -122.473955] // Golden Gate Park
		[37.79654155746526, -122.40533677470779], // House of Nanking
		[37.75800184534192, -122.38886935246086], // Just For You
		[37.79147905350631, -122.42761386168098], // Lafayette Park
		[38.558372505314615, -122.5244286982555], // Larkmead
		[37.766433792847764, -122.42222530377006], // Little Star
		[37.77922989881666, -122.51274181139564], // Louie's
		[37.82703217373967, -122.49926102888679], // Marin Headlands (top of Conzelman Road)
        // [37.758959, -122.454257] // Mount Sutro
		[37.8919636308939, -122.57054207456207], // Muir Woods
		[37.78472687826913, -122.40762201678848], // Powell Street Cable Car Turnaround
		[37.797042808079, -122.4369653834114], // Rose's
		[37.79913043263458, -122.41918501985168] // Swensen's
        // [37.801324, -122.458203] // Walt Disney Family Museum
	],
	[
		// [], // (Rehearsal dinner)
		[37.7973760290037, -122.44839075489232], // Presidio Social Club
		[37.791668, -122.40935], // The Stanford Court
		[-6.232738894708982, 29.881521783947] // Greystoke Mahale
	]
];

if (!window.console) { window.console = {log: function() {}}; };

$.fn.highlight = function() {
	$(this).addClass('highlight').siblings().removeClass('highlight');
	$(this).parent('.positions section, .positions ul').each(function() {
		$('#c-' + this.id).addClass('highlight').siblings().removeClass('highlight');
	}).show().siblings().hide();
	$(this).filter('.categories ul li').each(function() {
		$('#' + this.id.substr(2)).show().siblings().hide();
	});
};
$.fn.unhighlight = function() {
	$(this).removeClass('highlight');
};

// Don't scroll to the element with the ID that's being set as the hash.
var scrollLock = function(fn) {
	return function () {
		var scrollTop = $(window).scrollTop();
		var result = fn.apply(this, arguments);
		$(window).scrollTop(scrollTop);
		return result;
	};
};

$(function() {

	// Create a map, initially centered at our apartment.
	var map = new google.maps.Map(document.getElementsByClassName('map')[0], {
		center: new google.maps.LatLng(37.799105, -122.417801), // 1125 Union Street, San Francisco, CA
		mapTypeId: google.maps.MapTypeId.HYBRID,
		scrollwheel: false,
		zoom: 2
	});
	map.setTilt(0);

	// Start with the entire right column hidden.
	$('.positions section, .positions ul').hide()

	// Determine from the hash what the initial category is called.
	var category = 'wedding';
	if (window.location.hash) {
		var e = document.getElementById(window.location.hash.substr(1));
		var nodeName = e.nodeName.toLowerCase();
		if ('section' == nodeName) { category = e.id; }
		else if ('ul' == nodeName) { category = e.id; }
		else if ('li' == nodeName) { category = e.parentNode.id; }
	}
	$('#c-' + category).highlight();
	$(category).show();

	// Show the category's <section> or <ul> when its <li> is clicked.
	$('.positions section, .positions ul').each(function(i, e) {
		$('#c-' + this.id).click(function(event) {
			var c = this.id.substr(2);
			setTimeout(scrollLock(function() { window.location.hash = c; }), 0);
			$(this).highlight();
		});
	});

	$('.positions ul').hide().each(function(i, ul) {

		// Show the initial category's <ul>.
		if (category == this.id) { $(this).show(); }

		// Show markers on the map for each position in this category.
		// FIXME Don't show markers for positions in different categories?
		$(this).children('li').each(function(j, li) {
			var marker = new google.maps.Marker({
				map: map,
				position: new google.maps.LatLng(
					positions[i][j][0],
					positions[i][j][1]
				),
				title: $(this).children('h2').text()
			});

			// Highlight the position's <li> when its marker is clicked.
			google.maps.event.addListener(marker, 'click', function() {
				map.setCenter(marker.position);
				map.setZoom(16);
				setTimeout(function() { window.location.hash = li.id; }, 0);
				$(li).highlight();
			});

			// Center a position's marker when its <li> is clicked.
			$(this).click(function(event) {
				map.setCenter(marker.position);
				map.setZoom(16);
				var e = this;
				if ('a' == event.target.nodeName.toLowerCase()) {
					setTimeout(function() {
						window.location = event.target.getAttribute('href');
					}, 0)
				} else {
					setTimeout(scrollLock(function() {
						window.location.hash = e.id;
					}), 0);
				}
				$(this).highlight();
			});

			// Highlight the initial position's <li>.
			if (window.location.hash.substr(1) == this.id) {
				map.setCenter(marker.position);
				map.setZoom(16);
				$(this).highlight();
			}

		});

	});

	// Moving the map away unhighlights the text content.
	google.maps.event.addListener(map, 'center_changed', scrollLock(function() {
		setTimeout(function() { window.location.hash = ''; }, 0);
		$('.positions li').unhighlight();
	}));

});
