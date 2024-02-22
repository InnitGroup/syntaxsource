from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify

ClientPages = Blueprint('clientpages', __name__, template_folder="pages")

@ClientPages.route("/UploadMedia/PostImage.aspx", methods=["GET"])
def UploadMediaPostImage():
    seostr = request.args.get("seostr")
    filename = request.args.get("filename")
    if seostr is None or filename is None:
        return "Invalid request"
    return render_template("clientpages/screenshot.html", seostr=seostr, filename=filename)