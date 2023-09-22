# Infocenter (help.eclipse.org)

The online version of the internal Eclipse IDE help system hosted at https://help.eclipse.org.

This repository contains the required configuration files for creating docker images of the infocenters and deploying them to infrastructure hosted at the Eclipse Foundation.

## Policies

* To limit maintenance efforts, **the Eclipse Foundation only hosts Infocenters that are not older than two years or 8 quarterly releases**. See also https://www.eclipse.org/lists/cross-project-issues-dev/msg17274.html
* URLs of older infocenters are redirected to https://help.eclipse.org/latest
* If there is no security or other important issue, we deploy only the infocenter for a new release and re-deploy the infocenter for the previous release to add the header with the note that says “this is an outdated version of the Eclipse IDE documentation”
So we usually do not redeploy all infocenters with the latest release of the Eclipse platform during each quarterly release
* To avoid outdated infocenters being indexed by search engines (e.g. Google), we only allow robots to crawl https://help.eclipse.org/latest. Otherwise, we would end up with multiple results for the same help page in different versions of the infocenter. To make this work, an additional k8s route is used that links /latest to the latest infocenter pod. It has to be updated for every new release.

## Bugs

* General bugs in the infocenters will need to be reported to the Eclipse Platform team here: https://github.com/eclipse-platform/eclipse.platform/issues
* Bugs/typos in the documentation will need to be reported to the individual Eclipse project