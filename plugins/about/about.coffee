template = Handlebars.compile '    
    <div class="header">
        <a class="btn back">Back to playlist</a>
    </div>
    <div style="margin-top:20px; text-align:center">
    	<h1 style="background:url(assets/icons/42x42.png) center left no-repeat; font-weight: bold; font-size: 16px; display: inline-block; line-height: 42px; padding-left: 50px">Chromus v3.0.2</h1>

    	<a href="https://github.com/chromus/chromus" style="display:block;margin-top:15px; font-size: 14px;" target="_blank">github</a>
    </div>
'


about = $('<li>About</li>')
	.bind 'click', ->
		$('#main_menu').hide()
		$('#panel .container').html template()
		$('#panel').addClass('show')		


chromus.addMenu about