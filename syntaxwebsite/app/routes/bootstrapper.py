from flask import Blueprint, render_template, request, redirect, url_for, flash

BootstrapperRoute = Blueprint('BootstrapperRoute', __name__, template_folder='pages')

@BootstrapperRoute.route("/install/GetInstallerCdns.ashx", methods=["GET"])
def getinstallercdns():
    return "https://setup.syntax.eco/"
