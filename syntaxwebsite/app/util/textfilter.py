
from app.util.badwords import BadWords, ExtendedBadWords

class TextNotAllowedException(Exception):
    pass

def FilterText( 
    Text : str,
    ReplaceWith : str = "#",
    ThrowException : bool = False,
    UseExtendedBadWords : bool = False
):
    # This is a very basic filter, but it works for now
    
    OriginalText = Text
    Text = Text.lower()

    if UseExtendedBadWords:
        BadWords.extend(ExtendedBadWords)
    BadWords.sort(key=len, reverse=True)

    for BadWord in BadWords:
        if BadWord in Text:
            if ThrowException:
                raise TextNotAllowedException(f"Text contains a bad word, " + BadWord)
        Text = Text.replace(BadWord, ReplaceWith * len(BadWord))
    
    for i in range(len(OriginalText)):
        if OriginalText[i].isupper():
            Text = Text[:i] + Text[i].upper() + Text[i+1:]

    return Text

