import sys

import gitlab
import os
import subprocess


def clone_repo(repo_url, destination_path):
    print(f'Checking if {destination_path} exists')
    if not os.path.exists(destination_path):
        try:
            print(f'Cloning {repo_url} into {destination_path}')
            subprocess.run(['git', 'clone', repo_url, destination_path])
        except subprocess.CalledProcessError as e:
            print(f'An error occurred: {e}')
    else:
        print(f'Repository already exists at {destination_path}')


def clone_project(project, parent_dir):
    print(f'Cloning project {project.path} in {parent_dir}')
    project_web_url = project.web_url
    project_path = os.path.join(parent_dir, project.path)
    clone_repo(project_web_url, project_path)


def clone_wiki(project, parent_dir):
    print(f'Cloning wiki for project {project.path} in {parent_dir}')
    wiki_path = os.path.join(parent_dir, f"{project.path}.wiki")
    wiki_web_git_url = project.web_url + '.wiki.git'

    # if project.wikis.list() is empty, the wiki does not exist
    try:
        if project.wikis.list():
            clone_repo(wiki_web_git_url, wiki_path)
        else:
            print(f'No wiki found for {project.path}')
    except Exception as e:
        print(f'An error occurred: {e}')


# Recursive function to process groups and subgroups
def process_group(group_id, parent_dir, gitlab_client):
    # Get the group by ID or path
    print(f'Processing group {group_id}')
    group = gitlab_client.groups.get(group_id)

    # Make sure the directory structure matches the group structure
    group_dir = os.path.join(parent_dir, group.path)
    if not os.path.exists(group_dir):
        print(f'Creating directory {group_dir}')
        os.makedirs(group_dir)

    # Clone all projects in the current group
    # Note: this also gets projects that this group has access to
    projects = group.projects.list(get_all=True, owned=True)
    for project in projects:
        # ignore projects that are not in this group
        if project.namespace['id'] != group.id:
            print(f'Skipping project {project.path_with_namespace} because project.namespace["id"]:{project.namespace["id"]} != group.id:{group.id}')
            continue

        print(f'Processing project {project.path}')
        clone_project(project, group_dir)
        clone_wiki(gitlab_client.projects.get(project.id), group_dir)

    # Recursively process subgroups
    subgroups = group.subgroups.list(all=True)
    for subgroup in subgroups:
        print(f'Processing subgroup {subgroup.path}')
        process_group(subgroup.id, group_dir, gitlab_client)


def main():
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <gitlab_group_id>')
        sys.exit(1)

    gitlab_group_id = sys.argv[1]
    gitlab_token = os.environ.get('GITLAB_TOKEN')
    gitlab_host = os.environ.get('GITLAB_HOST', 'https://gitlab.com')

    if not gitlab_host.startswith('http'):
        gitlab_host = f'https://{gitlab_host}'

    gitlab_client = gitlab.Gitlab(gitlab_host, private_token=gitlab_token)

    try:
        process_group(gitlab_group_id, os.getcwd(), gitlab_client)
    except Exception as e:
        print(f'An error occurred: {e}')


if __name__ == '__main__':
    main()
