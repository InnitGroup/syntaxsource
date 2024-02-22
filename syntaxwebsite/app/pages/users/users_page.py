import timeago
from flask import Blueprint, render_template, request, redirect, url_for, flash
from app.util import auth
from app.models.user import User
from datetime import datetime, timedelta
from app.models.placeserver_players import PlaceServerPlayer

users_page = Blueprint('users_page', __name__, template_folder='templates')

@users_page.route('/users', methods=['GET'])
@auth.authenticated_required
def index_page():
    PageNumber = max( request.args.get('page', default = 1, type = int ), 1 )
    SearchQuery = request.args.get('q', default = None, type = str)
    UserLookupResults = None
    if SearchQuery is not None and SearchQuery != '':
        SearchQuery = SearchQuery.strip().replace( '%', '' )
        if len(SearchQuery) > 0 and len(SearchQuery) <= 32:
            UserLookupResults = User.query.filter( User.username.ilike( '%' + SearchQuery + '%' ) ).filter_by( accountstatus = 1 ).order_by( User.lastonline.desc() ).paginate( page = PageNumber, per_page = 15, error_out = False )
        else:
            flash('Invalid search query.', 'danger')
    
    if UserLookupResults is None:
        UserLookupResults = User.query.filter_by( accountstatus = 1 ).order_by( User.lastonline.desc() ).paginate( page = PageNumber, per_page = 15, error_out = False )
        SearchQuery = None

    def _get_timeago_time( userObj : User ) -> str:
        return timeago.format( userObj.lastonline, datetime.utcnow() )
    def _is_in_game( userObj : User ) -> bool:
        return PlaceServerPlayer.query.filter_by( userid = userObj.id ).first() is not None

    return render_template('users/index.html', UserLookupResults = UserLookupResults, SearchQuery = SearchQuery, MinOnlineTime = datetime.utcnow() - timedelta( minutes = 1 ), GetTimeAgoTime = _get_timeago_time, IsInGame = _is_in_game)

@users_page.route('/users', methods=['POST'])
@auth.authenticated_required
def index_page_post():
    return redirect( url_for( 'users_page.index_page', q = request.form.get('q', default = None, type = str) ) )