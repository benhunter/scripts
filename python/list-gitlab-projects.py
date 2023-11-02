import gitlab
import os
import sys


def main():
    url = os.environ.get('GITLAB_URL')
    token = os.environ.get('GITLAB_TOKEN')
    gl = gitlab.Gitlab(url, token)

    print(f'Getting projects')
    projects = gl.projects.list(iterator=True)
    for project in projects:
        print(project)
    sys.exit(0)


if __name__ == '__main__':
    main()
