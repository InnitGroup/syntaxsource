from app.extensions import db
from datetime import datetime

class ModeratorNote( db.Model ):
    id = db.Column( db.BigInteger, primary_key = True, autoincrement = True )
    user_id = db.Column( db.BigInteger, db.ForeignKey( 'user.id' ), index = True)
    note_creator_id = db.Column( db.BigInteger, db.ForeignKey( 'user.id' ), index = True)
    note = db.Column( db.Text )

    created_at = db.Column( db.DateTime, index=True, nullable=False )
    updated_at = db.Column( db.DateTime, index=True, nullable=False )

    related_action_id = db.Column( db.BigInteger, db.ForeignKey('user_ban.id'), nullable = True, index = True)

    def __init__( self, user_id, note_creator_id, note, related_action_id = None ):
        self.user_id = user_id
        self.note_creator_id = note_creator_id
        self.note = note
        self.related_action_id = related_action_id

        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def __repr__( self ):
        return '<ModeratorNote %r>' % self.id
    
class ModeratorNoteAttachment( db.Model ):
    id = db.Column( db.BigInteger, primary_key = True, autoincrement = True )
    moderator_note_id = db.Column( db.BigInteger, db.ForeignKey( 'moderator_note.id' ), index = True)
    attachment_hash = db.Column( db.String( 512 ), index = True, nullable = False )
    attachment_name = db.Column( db.String( 512 ), index = True, nullable = False )

    def __init__( self, moderator_note_id, attachment_hash, attachment_name ):
        self.moderator_note_id = moderator_note_id
        self.attachment_hash = attachment_hash
        self.attachment_name = attachment_name