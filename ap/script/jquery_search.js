/*
  James R. Griffin III
  02/25/12
  AuthorProfile
  Open Library Society
  jrgriffiniii@gmail.com
*/

function selectAuthorName(authorName) {
    $('#searchinput').val(authorName);
    setTimeout("$('.suggestion').fadeOut();", 'fast');
}

$(document).ready(function() {

    // This integrates with the search feature implemented in perl/lib/AuthorProfile/Web.pm
    $("#search").click(function() {
        window.location='/'+$('#searchinput').val();
    })

    $("#searchinput").click(function() {
        if($("#searchinput").val() == "Search for an author") {
            $("#searchinput").val("");
        }
    })

    $('#searchinput').keyup(function() {
	if($("#searchinput").val() == "") {
	    $(".suggestions").fadeOut('fast',function() {
		$(".suggestions").css('visibility','hidden');
	    });
	    return false;
	}

	$('#searchinput').addClass('load');

	// This is temporary.  Eventually, the MongoDB will be queried directly using its RESTful API.
	$.ajax({
	    type : 'POST',
	    url : '/devel/AuthorNameSearch.php',
	    dataType : 'json',
	    data: {
		authorNameQuery : $('#searchinput').val()
	    },
	    success : function(data) {
		$('.suggestion').remove()
		$('#searchinput').removeClass('load');
		if(data.length) {

		    for(var i=0;i<=data.length;i++) {
			$(".suggestions").append('<li onClick="selectAuthorName(\''+data[i].author.name+'\');" class="suggestion">'+data[i].author.name+'</li>');

		    }
		}
	    }
	});
	return false;
    });

    $("#searchinput").click(function() {
	if($("#searchinput").val() == "Search for an author") {
	    
	    $("#searchinput").val("");
	}
    })
})